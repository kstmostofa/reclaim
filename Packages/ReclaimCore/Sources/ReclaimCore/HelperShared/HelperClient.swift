import Foundation
import Security

/// The code identity used to pair the app and the helper: a code requirement naming one exact build by its
/// code hash. Without a paid signing certificate there is no team identity to pin instead.
public enum CodeIdentity {
    /// `cdhash H"…"` for the running program.
    public static func ownRequirement() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        return requirement(for: staticCode)
    }

    /// `cdhash H"…"` for the program at `path`.
    public static func requirement(forProgramAt path: String) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode
        else { return nil }
        return requirement(for: staticCode)
    }

    private static func requirement(for code: SecStaticCode) -> String? {
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any],
              let hash = dict[kSecCodeInfoUnique as String] as? Data
        else { return nil }
        return "cdhash H\"\(hash.map { String(format: "%02x", $0) }.joined())\""
    }
}

public enum HelperError: Error, LocalizedError, Equatable {
    /// The helper is missing, or refused this build of the app.
    case unavailable(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "The helper is not available: \(reason)"
        case .timedOut: "The helper did not answer."
        }
    }
}

/// Talks to the root helper over XPC.
public final class HelperClient: @unchecked Sendable {
    private let machService: String
    private let privileged: Bool
    /// The requirement the helper itself must meet, so the app never talks to an impostor.
    private let helperRequirement: String?

    public init(machService: String = HelperConstants.machService, privileged: Bool = true, helperRequirement: String?) {
        self.machService = machService
        self.privileged = privileged
        self.helperRequirement = helperRequirement
    }

    public func version(timeout: TimeInterval = 5) async throws -> Int {
        try await call(timeout: timeout) { proxy, done in proxy.version { done($0) } }
    }

    public func remove(paths: [String]) async throws -> [String: String] {
        try await call(timeout: 3600) { proxy, done in proxy.remove(paths: paths) { done($0) } }
    }

    public func measure(paths: [String]) async throws -> [String: Int64] {
        let sizes: [String: NSNumber] = try await call(timeout: 600) { proxy, done in proxy.measure(paths: paths) { done($0) } }
        return sizes.mapValues(\.int64Value)
    }

    public func deleteLocalSnapshots(dates: [String]) async throws -> [String: String] {
        try await call(timeout: 600) { proxy, done in proxy.deleteLocalSnapshots(dates: dates) { done($0) } }
    }

    /// Opens a connection for one call and closes it afterwards.
    private func call<T: Sendable>(
        timeout: TimeInterval,
        _ body: @escaping (HelperProtocol, @escaping @Sendable (T) -> Void) -> Void
    ) async throws -> T {
        let connection = NSXPCConnection(machServiceName: machService, options: privileged ? .privileged : [])
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        if let helperRequirement { connection.setCodeSigningRequirement(helperRequirement) }
        connection.resume()
        defer { connection.invalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                once.run { continuation.resume(throwing: HelperError.unavailable(error.localizedDescription)) }
            }
            guard let helper = proxy as? HelperProtocol else {
                once.run { continuation.resume(throwing: HelperError.unavailable("Unexpected interface.")) }
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.run { continuation.resume(throwing: HelperError.timedOut) }
            }
            body(helper) { value in once.run { continuation.resume(returning: value) } }
        }
    }
}

/// Runs a closure at most once, whichever of reply, error or timeout comes first.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
