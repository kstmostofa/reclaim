import Foundation

/// What a rule sees about one file or folder while the scanner walks the disk.
public struct EntryContext: Sendable {
    public let path: String
    public let name: String
    public let parentPath: String
    public let isDirectory: Bool
    public let modified: Date
    /// Names of every entry in the parent folder, including this one.
    public let siblings: [String]

    public init(path: String, name: String, parentPath: String, isDirectory: Bool, modified: Date, siblings: [String]) {
        self.path = path
        self.name = name
        self.parentPath = parentPath
        self.isDirectory = isDirectory
        self.modified = modified
        self.siblings = siblings
    }

    public var parentName: String { (parentPath as NSString).lastPathComponent }
}

/// Why an entry is suggested for deletion.
public struct RuleMatch: Sendable, Hashable, Codable {
    public var ruleID: String
    public var title: String
    public var category: SuggestionCategory
    public var level: SafetyLevel
    /// Why it is suggested.
    public var reason: String
    /// What happens after it is deleted.
    public var consequence: String

    public init(ruleID: String, title: String, category: SuggestionCategory, level: SafetyLevel, reason: String, consequence: String) {
        self.ruleID = ruleID
        self.title = title
        self.category = category
        self.level = level
        self.reason = reason
        self.consequence = consequence
    }
}

/// A rule decides, from one entry's context alone, whether that entry is a suggestion.
/// Once an entry matches, nothing inside it is checked again.
public protocol Rule: Sendable {
    func match(_ entry: EntryContext) -> RuleMatch?
}

/// An ordered list of rules; the first match wins.
public struct RuleSet: Sendable {
    public var rules: [any Rule]

    public init(_ rules: [any Rule]) {
        self.rules = rules
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        for rule in rules {
            if let match = rule.match(entry) { return match }
        }
        return nil
    }

    /// The built-in rules, with the user's own rules checked first.
    public static func defaults(
        home: String = NSHomeDirectory(),
        custom: [CustomRule] = [],
        appLocator: any AppLocating = InstalledApps(),
        downloadsAgeDays: Int = OldDownloadsRule.defaultDays,
        now: Date = Date()
    ) -> RuleSet {
        var rules: [any Rule] = custom
        rules += BuildCacheRules.all(home: home)
        rules += DependencyRules.all(home: home)
        rules += PackageManagerCacheRules.all(home: home)
        rules += MobileToolingRules.all(home: home)
        rules.append(LeftoverAppDataRule(home: home, apps: appLocator))
        rules += AppCacheRules.all(home: home)
        rules.append(TrashRule(home: home))
        rules.append(OldDownloadsRule(home: home, days: downloadsAgeDays, now: now))
        return RuleSet(rules)
    }
}

/// Matches a folder (or file) by name, optionally requiring a marker file beside it or inside it.
public struct NamedEntryRule: Rule {
    public let names: Set<String>
    public let directoriesOnly: Bool
    /// At least one of these must exist in the same folder as the entry.
    public let siblingMarkers: [String]
    /// The parent folder must have this name.
    public let parentName: String?
    /// This must exist inside the entry.
    public let childMarker: String?
    /// Entries whose path starts with one of these never match.
    public let excludedPrefixes: [String]
    public let template: RuleMatch

    public init(
        id: String, title: String, names: Set<String>, directoriesOnly: Bool = true,
        siblingMarkers: [String] = [], parentName: String? = nil, childMarker: String? = nil,
        excludedPrefixes: [String] = [], category: SuggestionCategory, level: SafetyLevel, reason: String, consequence: String
    ) {
        self.names = names
        self.directoriesOnly = directoriesOnly
        self.siblingMarkers = siblingMarkers
        self.parentName = parentName
        self.childMarker = childMarker
        self.excludedPrefixes = excludedPrefixes
        self.template = RuleMatch(ruleID: id, title: title, category: category, level: level, reason: reason, consequence: consequence)
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        guard names.contains(entry.name) else { return nil }
        if directoriesOnly && !entry.isDirectory { return nil }
        if let parentName, entry.parentName != parentName { return nil }
        if !siblingMarkers.isEmpty && !siblingMarkers.contains(where: entry.siblings.contains) { return nil }
        if excludedPrefixes.contains(where: entry.path.hasPrefix) { return nil }
        if let childMarker, access(entry.path + "/" + childMarker, F_OK) != 0 { return nil }
        return template
    }
}

/// Matches one fixed location, or every entry directly inside it.
public struct LocationRule: Rule {
    public let path: String
    public let matchChildren: Bool
    public let template: RuleMatch

    public init(id: String, title: String, path: String, matchChildren: Bool = false,
                category: SuggestionCategory, level: SafetyLevel, reason: String, consequence: String) {
        self.path = path
        self.matchChildren = matchChildren
        self.template = RuleMatch(ruleID: id, title: title, category: category, level: level, reason: reason, consequence: consequence)
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        if matchChildren {
            return entry.parentPath == path ? template : nil
        }
        return entry.path == path ? template : nil
    }
}
