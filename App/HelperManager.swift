import AppKit
import Foundation
import ReclaimCore

/// Installs, pairs and talks to the root helper.
///
/// Installing copies the helper out of the app into root-owned /Library/PrivilegedHelperTools and registers
/// it with launchd, pinned to this exact build of the app. macOS asks for an administrator password to do it.
/// After an app update the pin no longer matches, so the helper refuses the app until it is paired again.
@MainActor
final class HelperManager {
    enum Status: Equatable {
        case notInstalled
        /// Installed, but for another build of the app or an older protocol.
        case needsPairing
        case ready
    }

    enum InstallError: LocalizedError {
        case cannotIdentifyApp
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cannotIdentifyApp: "Reclaim could not read its own code signature."
            case .cancelled: "The installation was cancelled."
            case .failed(let message): message
            }
        }
    }

    private var bundledHelper: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/\(HelperConstants.label)").path
    }

    private var client: HelperClient {
        HelperClient(helperRequirement: CodeIdentity.requirement(forProgramAt: bundledHelper))
    }

    func status() async -> Status {
        let fm = FileManager.default
        guard fm.fileExists(atPath: HelperConstants.installedBinary), fm.fileExists(atPath: HelperConstants.launchdPlist) else {
            return .notInstalled
        }
        guard let version = try? await client.version(timeout: 3) else { return .needsPairing }
        return version == HelperConstants.protocolVersion ? .ready : .needsPairing
    }

    /// Installs or re-pairs the helper. macOS shows its own password dialog.
    func install() throws {
        guard let requirement = CodeIdentity.ownRequirement() else { throw InstallError.cannotIdentifyApp }
        let plist: [String: Any] = [
            "Label": HelperConstants.label,
            "ProgramArguments": [HelperConstants.installedBinary, "--client-requirement", requirement],
            "MachServices": [HelperConstants.machService: true],
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let label = HelperConstants.label
        let script = [
            "/bin/mkdir -p /Library/PrivilegedHelperTools",
            "/usr/bin/install -o root -g wheel -m 755 \(Self.quote(bundledHelper)) \(Self.quote(HelperConstants.installedBinary))",
            "/bin/echo \(plistData.base64EncodedString()) | /usr/bin/base64 -D > \(Self.quote(HelperConstants.launchdPlist))",
            "/usr/sbin/chown root:wheel \(Self.quote(HelperConstants.launchdPlist))",
            "/bin/chmod 644 \(Self.quote(HelperConstants.launchdPlist))",
            "(/bin/launchctl bootout system/\(label) 2>/dev/null; true)",
            "/bin/launchctl bootstrap system \(Self.quote(HelperConstants.launchdPlist))",
        ].joined(separator: " && ")
        try runAsAdministrator(script, prompt: "Reclaim needs your password to install its helper, which deletes system caches, logs and root-owned files.")
    }

    func uninstall() throws {
        let script = [
            "(/bin/launchctl bootout system/\(HelperConstants.label) 2>/dev/null; true)",
            "/bin/rm -f \(Self.quote(HelperConstants.launchdPlist)) \(Self.quote(HelperConstants.installedBinary))",
        ].joined(separator: " && ")
        try runAsAdministrator(script, prompt: "Reclaim needs your password to remove its helper.")
    }

    func remove(paths: [String]) async throws -> [String: String] {
        try await client.remove(paths: paths)
    }

    func measure(paths: [String]) async throws -> [String: Int64] {
        try await client.measure(paths: paths)
    }

    func deleteLocalSnapshots(dates: [String]) async throws -> [String: String] {
        try await client.deleteLocalSnapshots(dates: dates)
    }

    private func runAsAdministrator(_ shell: String, prompt: String) throws {
        let source = "do shell script \"\(Self.escapeForAppleScript(shell))\" with prompt \"\(Self.escapeForAppleScript(prompt))\" with administrator privileges"
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw InstallError.failed("Could not prepare the installer.") }
        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -128 { throw InstallError.cancelled }
            throw InstallError.failed(error[NSAppleScript.errorMessage] as? String ?? "The installer failed.")
        }
    }

    /// Single-quotes a value for the shell.
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func escapeForAppleScript(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Local Time Machine snapshots, listed by date.
enum LocalSnapshots {
    static func dates() async -> [String] {
        guard let result = try? await ProcessRunner().run("/usr/bin/tmutil", ["listlocalsnapshotdates", "/"], timeout: 30),
              result.status == 0
        else { return [] }
        return result.output.split(whereSeparator: \.isNewline).map(String.init).filter(SnapshotDate.isValid)
    }

    static func path(for date: String) -> String { "tmsnapshot:\(date)" }

    static func date(of path: String) -> String? {
        path.hasPrefix("tmsnapshot:") ? String(path.dropFirst("tmsnapshot:".count)) : nil
    }

    static func displayDate(_ date: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.date(from: date)
    }
}
