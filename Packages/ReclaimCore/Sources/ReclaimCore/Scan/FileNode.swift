import Foundation

/// One folder, or one file big enough to keep, in the scanned tree. Immutable once built.
public final class FileNode: Sendable, Identifiable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    /// Allocated bytes on disk, including everything inside a folder. Hard-linked files count once.
    public let size: Int64
    /// Number of files inside, or 1 for a file.
    public let fileCount: Int
    /// Newest modification date of anything inside.
    public let modified: Date
    /// Sub-folders, and files at or above the scanner's retention threshold, largest first.
    public let children: [FileNode]
    /// Set when a rule suggests this entry for deletion.
    public let match: RuleMatch?
    /// True when the folder could not be read, so its size is a lower bound.
    public let isUnreadable: Bool

    public var id: String { path }

    public init(name: String, path: String, isDirectory: Bool, size: Int64, fileCount: Int, modified: Date,
                children: [FileNode] = [], match: RuleMatch? = nil, isUnreadable: Bool = false) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.fileCount = fileCount
        self.modified = modified
        self.children = children
        self.match = match
        self.isUnreadable = isUnreadable
    }

    /// Bytes inside this folder not accounted for by `children` (small files not kept in the tree).
    public var otherFilesSize: Int64 {
        size - children.reduce(0) { $0 + $1.size }
    }

    /// Optional children for `OutlineGroup` and similar: nil for files.
    public var outlineChildren: [FileNode]? {
        isDirectory && !children.isEmpty ? children : nil
    }

    /// Finds the node at `path` by walking down from this one.
    public func node(at path: String) -> FileNode? {
        if path == self.path { return self }
        guard path.hasPrefix(self.path == "/" ? "/" : self.path + "/") else { return nil }
        for child in children {
            if let found = child.node(at: path) { return found }
        }
        return nil
    }
}
