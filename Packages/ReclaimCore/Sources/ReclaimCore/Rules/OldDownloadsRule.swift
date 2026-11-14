import Foundation

public struct OldDownloadsRule: Rule {
    public static let defaultDays = 90
    let path: String
    let days: Int
    let cutoff: Date

    public init(home: String, days: Int = OldDownloadsRule.defaultDays, now: Date = Date()) {
        path = home + "/Downloads"
        self.days = days
        cutoff = now.addingTimeInterval(-TimeInterval(days) * 24 * 3600)
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        guard entry.parentPath == path, entry.modified < cutoff, !entry.name.hasPrefix(".") else { return nil }
        return RuleMatch(
            ruleID: "downloads.old", title: "Old download", category: .oldDownloads, level: .personal,
            reason: "In Downloads and not changed for over \(days) days.",
            consequence: "Gone unless you can download it again."
        )
    }
}
