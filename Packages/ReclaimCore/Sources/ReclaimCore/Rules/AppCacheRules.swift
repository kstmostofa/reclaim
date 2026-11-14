import Foundation

/// Per-app caches and logs in the user's Library.
public enum AppCacheRules {
    public static func all(home: String) -> [any Rule] {
        [
            LocationRule(
                id: "app.caches", title: "App cache", path: home + "/Library/Caches", matchChildren: true,
                category: .appCache, level: .safe,
                reason: "Data an app keeps to work faster.",
                consequence: "The app rebuilds it; it may start slower once. Quit the app first if it is running."
            ),
            LocationRule(
                id: "app.logs", title: "Logs", path: home + "/Library/Logs", matchChildren: true,
                category: .logs, level: .safe,
                reason: "Log and crash-report files written by apps.",
                consequence: "Nothing is lost except the old logs themselves."
            ),
        ]
    }
}
