import Foundation

/// A rule the user adds in Settings: a path pattern plus a safety level.
///
/// Patterns are globs matched against the full path. `*` matches within one folder name, `**` across folders,
/// `?` one character, and a leading `~` is the home folder. A pattern that does not start with `/` or `~`
/// matches at any depth, so `api/storage/tenant*` is the same as `**/api/storage/tenant*`.
public struct CustomRule: Rule, Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var pattern: String
    public var level: SafetyLevel
    public var isEnabled: Bool

    private var regex: GlobRegex?

    public init(id: UUID = UUID(), name: String, pattern: String, level: SafetyLevel, isEnabled: Bool = true,
                home: String = NSHomeDirectory()) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.level = level
        self.isEnabled = isEnabled
        regex = GlobRegex(pattern: pattern, home: home)
    }

    private enum CodingKeys: String, CodingKey { case id, name, pattern, level, isEnabled }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            pattern: try c.decode(String.self, forKey: .pattern),
            level: try c.decode(SafetyLevel.self, forKey: .level),
            isEnabled: try c.decode(Bool.self, forKey: .isEnabled)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(pattern, forKey: .pattern)
        try c.encode(level, forKey: .level)
        try c.encode(isEnabled, forKey: .isEnabled)
    }

    /// False when the pattern cannot be turned into a matcher.
    public var isValid: Bool { regex != nil }

    public func matches(path: String) -> Bool {
        regex?.matches(path) ?? false
    }

    public func match(_ entry: EntryContext) -> RuleMatch? {
        guard isEnabled, matches(path: entry.path) else { return nil }
        return RuleMatch(
            ruleID: "custom.\(id.uuidString)", title: name, category: .custom, level: level,
            reason: "Matches your rule \(pattern).",
            consequence: "Whatever you decided when you wrote this rule."
        )
    }
}

/// A compiled glob. NSRegularExpression is immutable and safe to share across threads.
struct GlobRegex: @unchecked Sendable, Hashable {
    let source: String
    private let regex: NSRegularExpression

    init?(pattern: String, home: String) {
        var glob = pattern.trimmingCharacters(in: .whitespaces)
        guard !glob.isEmpty else { return nil }
        if glob == "~" || glob.hasPrefix("~/") {
            glob = home + glob.dropFirst()
        } else if !glob.hasPrefix("/") {
            glob = "**/" + glob
        }
        while glob.count > 1 && glob.hasSuffix("/") { glob.removeLast() }

        var out = "^"
        var chars = Array(glob)[...]
        while let c = chars.popFirst() {
            switch c {
            case "*":
                if chars.first == "*" {
                    chars.removeFirst()
                    if chars.first == "/" {
                        chars.removeFirst()
                        out += "(?:.*/)?"
                    } else {
                        out += ".*"
                    }
                } else {
                    out += "[^/]*"
                }
            case "?":
                out += "[^/]"
            default:
                out += NSRegularExpression.escapedPattern(for: String(c))
            }
        }
        out += "$"
        guard let regex = try? NSRegularExpression(pattern: out) else { return nil }
        self.source = out
        self.regex = regex
    }

    func matches(_ path: String) -> Bool {
        regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
    }

    static func == (lhs: GlobRegex, rhs: GlobRegex) -> Bool { lhs.source == rhs.source }
    func hash(into hasher: inout Hasher) { hasher.combine(source) }
}
