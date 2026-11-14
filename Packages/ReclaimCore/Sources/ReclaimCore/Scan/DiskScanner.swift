import Darwin
import Foundation
import os

/// Live counters a scan updates while it runs. Safe to read from any thread.
public final class ScanProgress: Sendable {
    public struct Snapshot: Sendable {
        public var files = 0
        public var folders = 0
        public var bytes: Int64 = 0
        public var unreadableFolders = 0
        public var currentPath = ""

        public init() {}
    }

    private let state = OSAllocatedUnfairLock(initialState: Snapshot())

    public init() {}

    public var snapshot: Snapshot { state.withLock { $0 } }

    func record(folder path: String, files: Int, bytes: Int64, unreadable: Bool) {
        state.withLock {
            $0.folders += 1
            $0.files += files
            $0.bytes += bytes
            if unreadable { $0.unreadableFolders += 1 }
            $0.currentPath = path
        }
    }
}

public struct ScanOptions: Sendable {
    /// Files at least this big are kept as their own nodes in the tree; smaller ones only count toward their folder.
    public var retainFilesFrom: Int64 = 1 << 20
    /// Folders down to this depth are scanned in parallel; deeper ones on the same task.
    public var parallelDepth = 4
    /// Paths skipped entirely, neither measured nor listed.
    public var excludedPaths: Set<String> = []

    public init() {}
}

/// Walks a folder tree, measuring allocated sizes and applying rules, without crossing into other volumes.
public struct DiskScanner: Sendable {
    /// The path macOS mounts the writable data volume at. Most of its top-level folders also appear at `/`.
    public static let dataVolumePath = "/System/Volumes/Data"

    /// Package-like folders whose insides are never suggested on their own.
    static let opaqueExtensions: Set<String> = [
        "app", "framework", "bundle", "plugin", "kext", "appex", "xpc",
        "photoslibrary", "musiclibrary", "tvlibrary", "photolibrary", "fcpbundle", "logicx", "xcarchive",
    ]

    public var rules: RuleSet
    public var options: ScanOptions

    public init(rules: RuleSet, options: ScanOptions = ScanOptions()) {
        self.rules = rules
        self.options = options
    }

    /// Scans `root`. Pass `dataVolumePath` to scan the whole disk: paths are then reported in their
    /// familiar form (`/Users/…` rather than `/System/Volumes/Data/Users/…`) wherever the two are the same folder.
    public func scan(root: String, progress: ScanProgress = ScanProgress()) async throws -> ScanResult {
        let started = Date()
        let root = root.count > 1 && root.hasSuffix("/") ? String(root.dropLast()) : root
        guard let rootStat = EntryStat.lstat(root), rootStat.isDirectory else {
            throw ScanError.notAFolder(root)
        }
        let walker = Walker(
            rules: rules, options: options, device: rootStat.device, links: HardLinkTracker(), progress: progress,
            mapsDataVolume: root == Self.dataVolumePath
        )
        let parent = (root as NSString).deletingLastPathComponent
        let name = root == "/" ? "/" : (root as NSString).lastPathComponent
        let pending = Walker.Pending(name: name, path: root, stat: rootStat, match: nil, rulesActive: true)
        let tree = await walker.scan(pending, parentPath: parent, depth: 0)
        try Task.checkCancellation()
        return ScanResult(root: tree, startedAt: started, duration: Date().timeIntervalSince(started),
                          unreadableFolders: progress.snapshot.unreadableFolders)
    }
}

public enum ScanError: Error, LocalizedError {
    case notAFolder(String)

    public var errorDescription: String? {
        switch self {
        case .notAFolder(let path): "\(path) is not a folder that can be read."
        }
    }
}

private struct Walker: Sendable {
    let rules: RuleSet
    let options: ScanOptions
    let device: dev_t
    let links: HardLinkTracker
    let progress: ScanProgress
    let mapsDataVolume: Bool

    struct Pending: Sendable {
        let name: String
        let path: String
        let stat: EntryStat
        let match: RuleMatch?
        let rulesActive: Bool
    }

    /// What one folder holds before its sub-folders are scanned.
    struct Level {
        var size: Int64
        var files = 0
        var newest: Date
        var fileNodes: [FileNode] = []
        var folders: [Pending] = []
        var unreadable = false
    }

    func scan(_ dir: Pending, parentPath: String, depth: Int) async -> FileNode {
        var level = read(dir, depth: depth)
        var children = level.fileNodes
        if depth < options.parallelDepth && level.folders.count > 1 {
            await withTaskGroup(of: FileNode.self) { group in
                for folder in level.folders {
                    group.addTask { await scan(folder, parentPath: dir.path, depth: depth + 1) }
                }
                for await node in group { children.append(node) }
            }
        } else {
            for folder in level.folders {
                children.append(scanSync(folder, depth: depth + 1))
            }
        }
        return assemble(dir, level: &level, children: children)
    }

    private func scanSync(_ dir: Pending, depth: Int) -> FileNode {
        var level = read(dir, depth: depth)
        var children = level.fileNodes
        if !Task.isCancelled {
            for folder in level.folders {
                children.append(scanSync(folder, depth: depth + 1))
            }
        }
        return assemble(dir, level: &level, children: children)
    }

    private func assemble(_ dir: Pending, level: inout Level, children: [FileNode]) -> FileNode {
        for child in children where child.isDirectory {
            level.size += child.size
            level.files += child.fileCount
            if child.modified > level.newest { level.newest = child.modified }
        }
        return FileNode(
            name: dir.name, path: dir.path, isDirectory: true, size: level.size, fileCount: level.files,
            modified: level.newest, children: children.sorted { $0.size > $1.size }, match: dir.match,
            isUnreadable: level.unreadable, owner: dir.stat.owner
        )
    }

    /// Lists one folder: measures its files, applies rules to every entry, and returns the sub-folders to scan.
    private func read(_ dir: Pending, depth: Int) -> Level {
        var level = Level(size: dir.stat.allocatedSize, newest: dir.stat.modified)
        guard !Task.isCancelled else { return level }
        guard let listing = DirectoryListing(path: dir.path) else {
            level.unreadable = true
            progress.record(folder: dir.path, files: 0, bytes: level.size, unreadable: true)
            return level
        }
        let siblings = dir.rulesActive ? listing.entries.map(\.name) : []
        let childRulesActive = dir.rulesActive && dir.match == nil
            && !DiskScanner.opaqueExtensions.contains((dir.name as NSString).pathExtension.lowercased())
        let prefix = dir.path == "/" ? "/" : dir.path + "/"
        var fileBytes: Int64 = 0

        for entry in listing.entries {
            var path = prefix + entry.name
            if options.excludedPaths.contains(path) { continue }
            if entry.stat.isDirectory {
                guard entry.stat.device == device else { continue }
                if mapsDataVolume && depth < 3 { path = familiarPath(for: path, stat: entry.stat) }
            }
            let match = childRulesActive ? rules.match(EntryContext(
                path: path, name: entry.name, parentPath: dir.path, isDirectory: entry.stat.isDirectory,
                modified: entry.stat.modified, siblings: siblings
            )) : nil

            if entry.stat.isDirectory {
                level.folders.append(Pending(name: entry.name, path: path, stat: entry.stat, match: match,
                                             rulesActive: childRulesActive && match == nil))
                continue
            }
            let size = SizeMeasurer.size(of: entry.stat, links: links)
            fileBytes += size
            level.files += 1
            if entry.stat.modified > level.newest { level.newest = entry.stat.modified }
            if entry.stat.isRegularFile && (size >= options.retainFilesFrom || match != nil) {
                level.fileNodes.append(FileNode(name: entry.name, path: path, isDirectory: false, size: size,
                                                fileCount: 1, modified: entry.stat.modified, match: match,
                                                owner: entry.stat.owner))
            }
        }
        level.size += fileBytes
        progress.record(folder: dir.path, files: level.files, bytes: fileBytes + dir.stat.allocatedSize, unreadable: false)
        return level
    }

    /// `/System/Volumes/Data/Users` → `/Users` when both names lead to the same folder.
    private func familiarPath(for path: String, stat: EntryStat) -> String {
        guard path.hasPrefix(DiskScanner.dataVolumePath + "/") else { return path }
        let short = String(path.dropFirst(DiskScanner.dataVolumePath.count))
        guard let other = EntryStat.lstat(short), other.device == stat.device, other.inode == stat.inode else {
            return path
        }
        return short
    }
}
