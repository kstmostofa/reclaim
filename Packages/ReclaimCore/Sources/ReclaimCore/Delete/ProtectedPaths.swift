import Darwin
import Foundation

/// The handful of catastrophic targets that are never listed or deleted, however they are spelled.
/// Everything inside them stays fair game.
public struct ProtectedPaths: Sendable {
    public enum Refusal: Error, Equatable, LocalizedError {
        case notAbsolute
        case relativeComponents
        case protected(String)

        public var errorDescription: String? {
            switch self {
            case .notAbsolute: "Only full paths can be deleted."
            case .relativeComponents: "Paths containing . or .. are refused."
            case .protected(let path): "\(path) is protected and is never deleted."
            }
        }
    }

    public let home: String
    private let exact: Set<String>
    /// Whole trees owned by macOS. `/usr/local` is the exception inside `/usr`.
    private static let systemTrees = ["/system", "/usr", "/bin", "/sbin"]
    private static let systemTreeExceptions = ["/usr/local/", "/system/volumes/data/"]

    public init(home: String = NSHomeDirectory()) {
        let home = Self.resolve(home) ?? home
        self.home = home
        var exact: Set<String> = [
            "/", "/System", "/Library", "/Applications", "/Users", "/Users/Shared", "/Volumes", "/Network", "/cores",
            "/private", "/private/var", "/private/etc", "/private/tmp", "/private/var/folders", "/private/var/log",
            "/private/var/db", "/private/var/vm", "/var", "/etc", "/tmp", "/opt", "/opt/homebrew", "/usr", "/usr/local",
            "/Library/Caches", "/Library/Logs", "/Library/Application Support", "/Library/Preferences",
            "/Applications/Utilities",
        ]
        exact.insert(home)
        let homeFolders = [
            "Desktop", "Documents", "Downloads", "Library", "Movies", "Music", "Pictures", "Public", "Applications",
            ".Trash", "Library/Application Support", "Library/Caches", "Library/Containers", "Library/Group Containers",
            "Library/Preferences", "Library/Logs", "Library/Mobile Documents", "Library/CloudStorage",
            "Library/Developer", "Library/Keychains", "Library/Mail", "Library/Messages", "Library/Photos",
        ]
        for folder in homeFolders { exact.insert(home + "/" + folder) }
        self.exact = Set(exact.map { $0.lowercased() })
    }

    public func isProtected(_ path: String) -> Bool {
        (try? validate(path)) == nil
    }

    /// Returns the path in canonical form when it may be deleted, or throws why not.
    @discardableResult
    public func validate(_ path: String) throws(Refusal) -> String {
        guard path.hasPrefix("/") else { throw .notAbsolute }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        if components.contains(where: { $0 == "." || $0 == ".." }) { throw .relativeComponents }
        let trimmed = "/" + components.joined(separator: "/")
        let canonical = Self.canonical(trimmed)

        // The default APFS volume ignores case, so compare without it.
        for candidate in Set([trimmed.lowercased(), canonical.lowercased()]) {
            if exact.contains(candidate) { throw .protected(path) }
            let parts = candidate.split(separator: "/")
            // Every top-level folder of the disk, such as /Applications or /.Spotlight-V100.
            if parts.count == 1 { throw .protected(path) }
            // Any user's home folder, any mounted volume's root, and the system folders in /private.
            if parts.count == 2 && (parts[0] == "users" || parts[0] == "volumes" || parts[0] == "private") {
                throw .protected(path)
            }
            for tree in Self.systemTrees where candidate == tree || candidate.hasPrefix(tree + "/") {
                if !Self.systemTreeExceptions.contains(where: { candidate.hasPrefix($0) }) { throw .protected(path) }
            }
        }
        return canonical
    }

    /// Resolves symlinks in the parent folders, keeps the last component as is (deleting a symlink removes
    /// only the link), and drops the data-volume prefix so both spellings of a folder compare equal.
    static func canonical(_ path: String) -> String {
        guard path != "/" else { return path }
        let parent = (path as NSString).deletingLastPathComponent
        let last = (path as NSString).lastPathComponent
        let resolvedParent = resolve(parent) ?? parent
        var result = resolvedParent == "/" ? "/" + last : resolvedParent + "/" + last
        let data = DiskScanner.dataVolumePath
        if result == data {
            result = "/"
        } else if result.hasPrefix(data + "/") {
            result = String(result.dropFirst(data.count))
        }
        // /tmp, /var and /etc are symlinks into /private.
        if let resolvedWhole = resolve(result), resolvedWhole != result, isSymlinkFreeAlias(result) {
            result = resolvedWhole
        }
        return result
    }

    /// realpath(3), or nil when the path does not exist.
    static func resolve(_ path: String) -> String? {
        guard let buffer = realpath(path, nil) else { return nil }
        defer { free(buffer) }
        return String(cString: buffer)
    }

    /// True when the last component is not itself a symlink, so resolving it names the same folder.
    private static func isSymlinkFreeAlias(_ path: String) -> Bool {
        guard let st = EntryStat.lstat(path) else { return false }
        return st.mode & S_IFMT != S_IFLNK
    }
}
