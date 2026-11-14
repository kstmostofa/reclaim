import Foundation

/// One entry the app suggests deleting.
public struct Suggestion: Sendable, Identifiable, Hashable {
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let modified: Date
    public let match: RuleMatch
    /// False when it belongs to another user, such as root, or its folder is not writable: deleting it
    /// then needs the helper.
    public let isDeletableByUser: Bool

    public var id: String { path }
    public var category: SuggestionCategory { match.category }
    public var level: SafetyLevel { match.level }

    public init(path: String, name: String, isDirectory: Bool, size: Int64, modified: Date, match: RuleMatch,
                isDeletableByUser: Bool = true) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.match = match
        self.isDeletableByUser = isDeletableByUser
    }

    init(_ node: FileNode, match: RuleMatch) {
        let parent = (node.path as NSString).deletingLastPathComponent
        self.init(path: node.path, name: node.name, isDirectory: node.isDirectory, size: node.size,
                  modified: node.modified, match: match,
                  isDeletableByUser: node.owner == getuid() && access(parent, W_OK) == 0)
    }

    public var deletionItem: DeletionItem {
        DeletionItem(path: path, size: size, title: match.title, category: category, level: level)
    }
}

public struct ScanResult: Sendable {
    public static let largeFileThreshold: Int64 = 500 * 1_000_000

    public let root: FileNode
    public let startedAt: Date
    public let duration: TimeInterval
    public let unreadableFolders: Int

    public init(root: FileNode, startedAt: Date, duration: TimeInterval, unreadableFolders: Int) {
        self.root = root
        self.startedAt = startedAt
        self.duration = duration
        self.unreadableFolders = unreadableFolders
    }

    /// Every entry a rule matched, largest first. Nothing inside a matched entry is listed separately.
    public func suggestions() -> [Suggestion] {
        var out: [Suggestion] = []
        func visit(_ node: FileNode) {
            if let match = node.match {
                if node.size > 0 { out.append(Suggestion(node, match: match)) }
                return
            }
            node.children.forEach(visit)
        }
        visit(root)
        return out.sorted { $0.size > $1.size }
    }

    /// Files of at least `threshold` bytes that no rule already covers, skipping the insides of app bundles
    /// and libraries. Listed as Personal: only you can tell whether you still need them.
    public func largeFiles(threshold: Int64 = largeFileThreshold) -> [Suggestion] {
        var out: [Suggestion] = []
        let match = RuleMatch(
            ruleID: "largeFiles", title: "Large file", category: .largeFiles, level: .personal,
            reason: "Larger than \(ByteCountFormatter.string(fromByteCount: threshold, countStyle: .file)).",
            consequence: "Gone for good unless you have another copy."
        )
        func visit(_ node: FileNode) {
            guard node.match == nil, node.size >= threshold else { return }
            if !node.isDirectory {
                out.append(Suggestion(node, match: match))
                return
            }
            if DiskScanner.opaqueExtensions.contains((node.name as NSString).pathExtension.lowercased()) { return }
            node.children.forEach(visit)
        }
        visit(root)
        return out.sorted { $0.size > $1.size }
    }
}
