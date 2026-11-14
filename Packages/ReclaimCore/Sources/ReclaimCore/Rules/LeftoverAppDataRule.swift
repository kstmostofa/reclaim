import CoreServices
import Foundation

/// Answers whether an app with a given bundle identifier is installed.
public protocol AppLocating: Sendable {
    func isInstalled(bundleID: String) -> Bool
}

/// Looks up installed apps in the usual app folders and through Launch Services.
public final class InstalledApps: AppLocating, @unchecked Sendable {
    private let lock = NSLock()
    private var knownIDs: Set<String>?
    private let searchFolders: [String]

    public init(home: String = NSHomeDirectory()) {
        searchFolders = [
            "/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
            "/System/Library/CoreServices", home + "/Applications",
        ]
    }

    public func isInstalled(bundleID: String) -> Bool {
        if installedIDs().contains(bundleID.lowercased()) { return true }
        if let urls = LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL],
           !urls.isEmpty {
            return true
        }
        return false
    }

    private func installedIDs() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        if let knownIDs { return knownIDs }
        var ids = Set<String>()
        let fm = FileManager.default
        for folder in searchFolders {
            guard let names = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            for name in names where name.hasSuffix(".app") {
                if let id = Bundle(path: folder + "/" + name)?.bundleIdentifier {
                    ids.insert(id.lowercased())
                }
            }
        }
        knownIDs = ids
        return ids
    }
}

/// Data folders named after an app's bundle identifier, when that app is no longer installed.
public struct LeftoverAppDataRule: Rule {
    let parents: Set<String>
    let apps: any AppLocating

    public init(home: String, apps: any AppLocating) {
        parents = [
            home + "/Library/Containers",
            home + "/Library/Application Support",
        ]
        self.apps = apps
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        guard entry.isDirectory, parents.contains(entry.parentPath),
              Self.looksLikeBundleID(entry.name),
              !entry.name.lowercased().hasPrefix("com.apple."),
              !Self.ownerCandidates(entry.name).contains(where: apps.isInstalled)
        else { return nil }
        return RuleMatch(
            ruleID: "leftovers.appData", title: "Data of an uninstalled app", category: .appLeftovers, level: .personal,
            reason: "No installed app has the identifier \(entry.name).",
            consequence: "If you reinstall the app, it starts without its old settings and data."
        )
    }

    /// The name itself, then each shorter prefix: an extension's or helper's identifier extends its app's,
    /// so com.foo.App.ShareExtension belongs to com.foo.App.
    static func ownerCandidates(_ bundleID: String) -> [String] {
        var out = [bundleID]
        var candidate = Substring(bundleID)
        while let dot = candidate.lastIndex(of: "."), candidate[..<dot].contains(".") {
            candidate = candidate[..<dot]
            out.append(String(candidate))
        }
        return out
    }

    /// Reverse-DNS names such as com.docker.docker.
    static func looksLikeBundleID(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }
    }
}
