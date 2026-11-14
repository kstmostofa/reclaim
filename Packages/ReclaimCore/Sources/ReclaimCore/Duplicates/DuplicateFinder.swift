import CryptoKit
import Darwin
import Foundation
import os

/// One copy in a group of identical files.
public struct DuplicateFile: Sendable, Identifiable, Hashable {
    public let path: String
    public let size: Int64
    public let modified: Date
    /// Copies with the same storage key are APFS clones of each other; nil when it could not be read.
    public let storageKey: CloneDetector.Fingerprint?

    public init(path: String, size: Int64, modified: Date, storageKey: CloneDetector.Fingerprint?) {
        self.path = path
        self.size = size
        self.modified = modified
        self.storageKey = storageKey
    }

    public var id: String { path }
    public var name: String { (path as NSString).lastPathComponent }
    public var folder: String { (path as NSString).deletingLastPathComponent }
}

/// Files with identical contents.
public struct DuplicateGroup: Sendable, Identifiable, Hashable {
    public let hash: String
    public let size: Int64
    /// Oldest first.
    public let files: [DuplicateFile]

    public init(hash: String, size: Int64, files: [DuplicateFile]) {
        self.hash = hash
        self.size = size
        self.files = files
    }

    public var id: String { hash }

    /// Bytes freed by keeping one copy and deleting the rest. Copies that share storage with another
    /// count once, so this is what deleting really frees.
    public var reclaimable: Int64 {
        Int64(max(0, distinctStorage - 1)) * size
    }

    /// Number of copies that use their own storage.
    public var distinctStorage: Int {
        var keys = Set<CloneDetector.Fingerprint>()
        var unknown = 0
        for file in files {
            if let key = file.storageKey { keys.insert(key) } else { unknown += 1 }
        }
        return keys.count + unknown
    }

    /// True when this copy shares its storage with another copy in the group.
    public func sharesStorage(_ file: DuplicateFile) -> Bool {
        guard let key = file.storageKey else { return false }
        return files.contains { $0.path != file.path && $0.storageKey == key }
    }

    public func deletionItem(for file: DuplicateFile) -> DeletionItem {
        DeletionItem(path: file.path, size: sharesStorage(file) ? 0 : file.size, title: "Duplicate of \(file.name)",
                     category: .duplicates, level: .personal)
    }
}

public final class DuplicateProgress: Sendable {
    public struct Snapshot: Sendable {
        public var candidates = 0
        public var filesRead = 0
        public var bytesRead: Int64 = 0
        public var stage = ""

        public init() {}
    }

    private let state = OSAllocatedUnfairLock(initialState: Snapshot())

    public init() {}

    public var snapshot: Snapshot { state.withLock { $0 } }

    func update(_ change: @Sendable (inout Snapshot) -> Void) {
        state.withLock { change(&$0) }
    }
}

/// Finds identical files: grouped by size, then by a hash of their first and last blocks, then by a full
/// SHA-256, so only real candidates are read in full.
public struct DuplicateFinder: Sendable {
    public static let defaultMinimumSize: Int64 = 1 << 20
    static let edgeBytes = 64 * 1024

    public var minimumSize: Int64
    /// Folders whose files are never compared, in addition to app bundles, libraries and rule matches.
    public var skippedPrefixes: [String]
    /// How many files are read at the same time.
    public var parallelReads = 4

    public init(minimumSize: Int64 = DuplicateFinder.defaultMinimumSize,
                skippedPrefixes: [String] = DuplicateFinder.defaultSkippedPrefixes()) {
        self.minimumSize = minimumSize
        self.skippedPrefixes = skippedPrefixes
    }

    /// Folders of installed packages. Copies across them belong to tools and projects, not to you.
    /// Hidden folders, such as ~/.vscode, are skipped for the same reason.
    static let packageFolders: Set<String> = ["node_modules", "site-packages", "dist-packages", "vendor", "Pods"]

    /// App, system and shared app data (such as databases tools install in /Users/Shared): copies there are
    /// usually deliberate, and deleting one can break the app.
    public static func defaultSkippedPrefixes(home: String = NSHomeDirectory()) -> [String] {
        [home + "/Library/", "/Library/", "/System/", "/private/", "/usr/", "/opt/", "/Applications/", "/Users/Shared/"]
    }

    /// Candidates from a scanned tree: files at or above the minimum size, outside matched suggestions,
    /// bundles, libraries, hidden and package folders, and the skipped folders. The tree keeps files of 1 MB and up.
    public func candidates(in tree: FileNode) -> [String] {
        var out: [String] = []
        func visit(_ node: FileNode) {
            guard node.match == nil else { return }
            // The scanned root itself may sit under a skipped prefix, such as /System/Volumes/Data.
            if node !== tree && skippedPrefixes.contains(where: { node.path.hasPrefix($0) || node.path + "/" == $0 }) {
                return
            }
            if node.isDirectory {
                let ext = (node.name as NSString).pathExtension.lowercased()
                if DiskScanner.opaqueExtensions.contains(ext) { return }
                if node !== tree && (node.name.hasPrefix(".") || Self.packageFolders.contains(node.name)) { return }
                node.children.forEach(visit)
            } else if node.size >= minimumSize {
                out.append(node.path)
            }
        }
        visit(tree)
        return out
    }

    public func find(in tree: FileNode, progress: DuplicateProgress = DuplicateProgress()) async throws -> [DuplicateGroup] {
        try await find(paths: candidates(in: tree), progress: progress)
    }

    /// Groups of identical files among `paths`, largest reclaimable first.
    public func find(paths: [String], progress: DuplicateProgress = DuplicateProgress()) async throws -> [DuplicateGroup] {
        progress.update { $0.stage = "Comparing sizes"; $0.candidates = paths.count }

        // 1. Size, counting each hard-linked file once.
        var seenInodes = Set<[UInt64]>()
        var bySize: [Int64: [(path: String, modified: Date)]] = [:]
        for path in paths {
            var st = stat()
            guard lstat(path, &st) == 0, st.st_mode & S_IFMT == S_IFREG, st.st_size >= minimumSize else { continue }
            guard seenInodes.insert([UInt64(st.st_dev), UInt64(st.st_ino)]).inserted else { continue }
            let modified = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
            bySize[Int64(st.st_size), default: []].append((path, modified))
        }
        let sameSize = bySize.filter { $0.value.count > 1 }
        try Task.checkCancellation()

        // 2. First and last blocks.
        progress.update { $0.stage = "Comparing file edges" }
        var byEdges: [String: [(path: String, modified: Date, size: Int64)]] = [:]
        let edgeJobs = sameSize.flatMap { size, files in files.map { ($0.path, $0.modified, size) } }
        for (key, job) in try await hashAll(edgeJobs, progress: progress, hash: { Self.edgeHash(path: $0.0, size: $0.2) }) {
            byEdges["\(job.2)-\(key)", default: []].append(job)
        }
        try Task.checkCancellation()

        // 3. Full contents.
        progress.update { $0.stage = "Comparing contents" }
        let fullJobs = byEdges.values.filter { $0.count > 1 }.flatMap { $0 }
        var byContent: [String: [DuplicateFile]] = [:]
        for (key, job) in try await hashAll(fullJobs, progress: progress, hash: { Self.fullHash(path: $0.0) }) {
            let file = DuplicateFile(path: job.0, size: job.2, modified: job.1,
                                     storageKey: CloneDetector.fingerprint(path: job.0, size: job.2))
            byContent["\(job.2)-\(key)", default: []].append(file)
        }

        progress.update { $0.stage = "Done" }
        return byContent.compactMap { key, files in
            guard files.count > 1 else { return nil }
            return DuplicateGroup(hash: key, size: files[0].size, files: files.sorted { $0.modified < $1.modified })
        }
        .sorted { ($0.reclaimable, $0.size) > ($1.reclaimable, $1.size) }
    }

    /// Hashes jobs `parallelReads` at a time; jobs whose file cannot be read are dropped.
    private func hashAll<Job: Sendable>(
        _ jobs: [Job], progress: DuplicateProgress, hash: @escaping @Sendable (Job) -> (String, Int64)?
    ) async throws -> [(String, Job)] {
        try await withThrowingTaskGroup(of: (String, Job)?.self) { group in
            var results: [(String, Job)] = []
            var iterator = jobs.makeIterator()
            func addNext() -> Bool {
                guard let job = iterator.next() else { return false }
                group.addTask {
                    try Task.checkCancellation()
                    guard let (key, bytes) = hash(job) else { return nil }
                    progress.update { $0.filesRead += 1; $0.bytesRead += bytes }
                    return (key, job)
                }
                return true
            }
            for _ in 0..<max(1, parallelReads) where addNext() {}
            while let result = try await group.next() {
                if let result { results.append(result) }
                _ = addNext()
            }
            return results
        }
    }

    /// SHA-256 of the first and last 64 KB. Returns the hash and the bytes read.
    static func edgeHash(path: String, size: Int64) -> (String, Int64)? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        do {
            var hasher = SHA256()
            let head = try handle.read(upToCount: edgeBytes) ?? Data()
            hasher.update(data: head)
            var read = Int64(head.count)
            if size > Int64(edgeBytes) {
                try handle.seek(toOffset: UInt64(max(Int64(edgeBytes), size - Int64(edgeBytes))))
                let tail = try handle.read(upToCount: edgeBytes) ?? Data()
                hasher.update(data: tail)
                read += Int64(tail.count)
            }
            return (hex(hasher.finalize()), read)
        } catch {
            return nil
        }
    }

    /// SHA-256 of the whole file, read in 1 MB chunks.
    static func fullHash(path: String) -> (String, Int64)? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var read: Int64 = 0
        do {
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
                if Task.isCancelled { return nil }
                hasher.update(data: chunk)
                read += Int64(chunk.count)
            }
        } catch {
            return nil
        }
        return (hex(hasher.finalize()), read)
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Which copy in each group to keep; every other copy is ticked.
public enum KeepChoice: Sendable, Hashable {
    case oldest
    case newest
    /// Keep the copy inside this folder, if the group has one there.
    case inFolder(String)

    /// The copies to delete from `group`, or none when the choice does not apply to it.
    public func copiesToDelete(in group: DuplicateGroup) -> [DuplicateFile] {
        let keep: DuplicateFile?
        switch self {
        case .oldest:
            keep = group.files.min { $0.modified < $1.modified }
        case .newest:
            keep = group.files.max { $0.modified < $1.modified }
        case .inFolder(let folder):
            keep = group.files.first { $0.path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/") }
        }
        guard let keep else { return [] }
        return group.files.filter { $0.path != keep.path }
    }
}
