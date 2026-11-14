import Foundation

public struct OldDownloadsRule: Rule {
    public static let age: TimeInterval = 90 * 24 * 3600
    let path: String
    let cutoff: Date

    public init(home: String, now: Date = Date()) {
        path = home + "/Downloads"
        cutoff = now.addingTimeInterval(-Self.age)
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        guard entry.parentPath == path, entry.modified < cutoff, !entry.name.hasPrefix(".") else { return nil }
        return RuleMatch(
            ruleID: "downloads.old", title: "Old download", category: .oldDownloads, level: .personal,
            reason: "In Downloads and not changed for over 90 days.",
            consequence: "Gone unless you can download it again."
        )
    }
}
