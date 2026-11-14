import Darwin
import Foundation

/// What the root helper may delete: only inside a fixed list of system folders and the requesting user's
/// home folder, never a protected path, judged after resolving symlinks.
///
/// The helper runs as root, so this is the line between "cleans up caches" and "deletes whatever it is told".
public struct PathPolicy: Sendable {
    public static let systemRoots = ["/Library/Caches", "/Library/Logs", "/private/var/log"]

    public enum Refusal: Error, Equatable, LocalizedError {
        case notAbsolute
        case relativeComponents
        case missingParent
        case outsideAllowedFolders
        case protected

        public var errorDescription: String? {
            switch self {
            case .notAbsolute: "Only full paths are accepted."
            case .relativeComponents: "Paths containing . or .. are refused."
            case .missingParent: "Its folder does not exist."
            case .outsideAllowedFolders: "The helper only deletes in system cache and log folders and in your home folder."
            case .protected: "This folder is protected and is never deleted."
            }
        }
    }

    /// Where a deletion is allowed, split for `SafeRemover`: a symlink-free parent folder and one name in it.
    public struct Target: Equatable, Sendable {
        public let parent: String
        public let name: String

        public var path: String { parent == "/" ? "/" + name : parent + "/" + name }
    }

    let roots: [String]
    let home: String
    let protectedPaths: ProtectedPaths

    /// `home` must come from the requesting user's identity, never from the request itself.
    public init(home: String, systemRoots: [String] = PathPolicy.systemRoots) {
        let resolvedHome = ProtectedPaths.resolve(home) ?? home
        self.home = resolvedHome
        roots = systemRoots.map { ProtectedPaths.resolve($0) ?? $0 } + [resolvedHome]
        protectedPaths = ProtectedPaths(home: resolvedHome)
    }

    public func check(_ path: String) throws(Refusal) -> Target {
        guard path.hasPrefix("/"), !path.contains("\0") else { throw .notAbsolute }
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if components.contains(where: { $0 == "." || $0 == ".." }) { throw .relativeComponents }
        guard let name = components.last else { throw .protected }

        let parentPath = "/" + components.dropLast().joined(separator: "/")
        guard var parent = ProtectedPaths.resolve(parentPath) else { throw .missingParent }
        let data = DiskScanner.dataVolumePath
        if parent == data {
            parent = "/"
        } else if parent.hasPrefix(data + "/") {
            parent = String(parent.dropFirst(data.count))
        }
        let target = Target(parent: parent, name: name)

        // Strictly inside an allowed folder, compared without case like the volume itself.
        let lower = target.path.lowercased()
        guard roots.contains(where: { lower.hasPrefix($0.lowercased() + "/") }) else { throw .outsideAllowedFolders }
        guard !protectedPaths.isProtected(target.path) else { throw .protected }
        return target
    }
}

/// Deletes a policy-approved target without following symlinks anywhere on the way.
///
/// The parent folder is opened one component at a time from `/` with `O_NOFOLLOW`, so a folder swapped
/// for a symlink after the policy check makes the open fail instead of redirecting the delete. The last
/// step uses `removefileat`, which removes a symlink itself rather than its target and never crosses into
/// another volume.
public enum SafeRemover {
    /// Returns nil on success, or why it failed.
    public static func remove(_ target: PathPolicy.Target) -> String? {
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { return String(cString: strerror(errno)) }
        for component in target.parent.split(separator: "/") {
            let next = openat(fd, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            let code = errno
            close(fd)
            guard next >= 0 else {
                return code == ELOOP || code == ENOTDIR
                    ? "Refused: a folder on the way was replaced by a link."
                    : String(cString: strerror(code))
            }
            fd = next
        }
        defer { close(fd) }
        var st = stat()
        guard fstatat(fd, target.name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { return "It no longer exists." }
        guard removefileat(fd, target.name, nil, removefile_flags_t(REMOVEFILE_RECURSIVE)) == 0 else {
            return String(cString: strerror(errno))
        }
        return nil
    }
}
