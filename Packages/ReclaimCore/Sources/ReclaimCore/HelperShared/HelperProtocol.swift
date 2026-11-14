import Foundation

/// Names shared by the app, the helper and its launchd definition.
public enum HelperConstants {
    public static let label = "io.github.kstmostofa.reclaim.helper"
    public static let machService = label
    public static let installedBinary = "/Library/PrivilegedHelperTools/\(label)"
    public static let launchdPlist = "/Library/LaunchDaemons/\(label).plist"
    /// Bumped whenever the protocol changes, so an old helper is replaced.
    public static let protocolVersion = 1
}

/// What the app may ask the root helper. Every path is checked against `PathPolicy` inside the helper.
@objc(ReclaimHelperProtocol)
public protocol HelperProtocol {
    /// The helper's protocol version.
    func version(reply: @escaping @Sendable (Int) -> Void)

    /// Deletes each path the policy allows. The reply maps every path to an empty string on success, or the
    /// reason it was not deleted.
    func remove(paths: [String], reply: @escaping @Sendable ([String: String]) -> Void)

    /// Measures the allocated size of each path the policy allows; paths it refuses or cannot read are left out.
    func measure(paths: [String], reply: @escaping @Sendable ([String: NSNumber]) -> Void)

    /// Deletes local Time Machine snapshots by their date, as `tmutil listlocalsnapshotdates` prints them.
    func deleteLocalSnapshots(dates: [String], reply: @escaping @Sendable ([String: String]) -> Void)
}

public enum SnapshotDate {
    /// `2026-11-14-101500`: the only form passed on to tmutil.
    public static func isValid(_ text: String) -> Bool {
        let digits = text.split(separator: "-")
        return digits.count == 4 && zip(digits, [4, 2, 2, 6]).allSatisfy { part, length in
            part.count == length && part.allSatisfy(\.isASCII) && part.allSatisfy(\.isNumber)
        }
    }
}
