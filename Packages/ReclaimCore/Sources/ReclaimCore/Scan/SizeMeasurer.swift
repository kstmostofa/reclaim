import Darwin
import Foundation
import os

/// The parts of `lstat` the scanner needs.
struct EntryStat: Sendable {
    let mode: mode_t
    let device: dev_t
    let inode: ino_t
    let linkCount: nlink_t
    let owner: uid_t
    /// Allocated bytes: `st_blocks` × 512, so sparse files report what they really occupy.
    let allocatedSize: Int64
    let modified: Date

    init(_ st: stat) {
        mode = st.st_mode
        device = st.st_dev
        inode = st.st_ino
        linkCount = st.st_nlink
        owner = st.st_uid
        allocatedSize = Int64(st.st_blocks) * 512
        modified = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
    }

    var isDirectory: Bool { mode & S_IFMT == S_IFDIR }
    var isRegularFile: Bool { mode & S_IFMT == S_IFREG }

    static func lstat(_ path: String) -> EntryStat? {
        var st = Darwin.stat()
        guard Darwin.lstat(path, &st) == 0 else { return nil }
        return EntryStat(st)
    }
}

/// Remembers hard-linked files so each is counted once, wherever its other names are.
final class HardLinkTracker: Sendable {
    private struct Key: Hashable {
        let device: dev_t
        let inode: ino_t
    }

    private let seen = OSAllocatedUnfairLock(initialState: Set<Key>())

    /// True the first time this file is seen.
    func firstSighting(_ entry: EntryStat) -> Bool {
        let key = Key(device: entry.device, inode: entry.inode)
        return seen.withLock { $0.insert(key).inserted }
    }
}

/// Measures one path's allocated size the way `du` does, without building a tree.
public enum SizeMeasurer {
    /// Allocated bytes of a file, or of a folder and everything inside it. Does not follow symlinks
    /// or cross into other volumes; hard-linked files count once.
    public static func allocatedSize(of path: String) -> Int64 {
        guard let root = EntryStat.lstat(path) else { return 0 }
        let links = HardLinkTracker()
        return measure(path: path, entry: root, device: root.device, links: links)
    }

    static func size(of entry: EntryStat, links: HardLinkTracker) -> Int64 {
        if !entry.isDirectory && entry.linkCount > 1 && !links.firstSighting(entry) { return 0 }
        return entry.allocatedSize
    }

    private static func measure(path: String, entry: EntryStat, device: dev_t, links: HardLinkTracker) -> Int64 {
        var total = size(of: entry, links: links)
        guard entry.isDirectory, let listing = DirectoryListing(path: path) else { return total }
        for child in listing.entries where child.stat.device == device {
            if child.stat.isDirectory {
                total += measure(path: path + "/" + child.name, entry: child.stat, device: device, links: links)
            } else {
                total += size(of: child.stat, links: links)
            }
        }
        return total
    }
}

/// The entries of one folder, each with its `lstat`.
struct DirectoryListing {
    struct Entry {
        let name: String
        let stat: EntryStat
    }

    let entries: [Entry]

    init?(path: String) {
        guard let dir = opendir(path) else { return nil }
        defer { closedir(dir) }
        let fd = dirfd(dir)
        var entries: [Entry] = []
        while let ent = readdir(dir) {
            let length = Int(ent.pointee.d_namlen)
            let name = withUnsafeBytes(of: &ent.pointee.d_name) { raw in
                String(decoding: UnsafeRawBufferPointer(rebasing: raw[0..<length]), as: UTF8.self)
            }
            if name == "." || name == ".." { continue }
            var st = Darwin.stat()
            guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
            entries.append(Entry(name: name, stat: EntryStat(st)))
        }
        self.entries = entries
    }
}
