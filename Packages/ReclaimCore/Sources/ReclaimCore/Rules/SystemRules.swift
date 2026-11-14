import Foundation

/// Caches and logs kept for the whole Mac. Most belong to root, so deleting them needs the helper.
public enum SystemRules {
    public static func all() -> [any Rule] {
        [
            LocationRule(
                id: "system.caches", title: "System cache", path: "/Library/Caches", matchChildren: true,
                category: .system, level: .safe,
                reason: "Data macOS or an app keeps for every user to work faster.",
                consequence: "Recreated when needed. Items macOS protects are skipped."
            ),
            LocationRule(
                id: "system.logs", title: "System logs", path: "/Library/Logs", matchChildren: true,
                category: .system, level: .safe,
                reason: "Logs and crash reports written by the system and installers.",
                consequence: "Nothing is lost except the old logs themselves."
            ),
            LocationRule(
                id: "system.varLog", title: "System logs", path: "/private/var/log", matchChildren: true,
                category: .system, level: .safe,
                reason: "Log files written by system services.",
                consequence: "Nothing is lost except the old logs themselves. Services start new ones."
            ),
        ]
    }
}
