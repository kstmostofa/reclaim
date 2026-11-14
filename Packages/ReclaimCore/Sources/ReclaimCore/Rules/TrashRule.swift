import Foundation

public struct TrashRule: Rule {
    let path: String

    public init(home: String) {
        path = home + "/.Trash"
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        guard entry.parentPath == path else { return nil }
        return RuleMatch(
            ruleID: "trash", title: "In the Trash", category: .trash, level: .safe,
            reason: "You already moved this to the Trash.",
            consequence: "Removed for good, as if you had emptied the Trash."
        )
    }
}
