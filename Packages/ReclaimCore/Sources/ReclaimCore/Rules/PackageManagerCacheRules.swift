import Foundation

/// Download caches shared by every project on the Mac.
public enum PackageManagerCacheRules {
    public static func all(home: String) -> [any Rule] {
        let safe: [(String, String, String)] = [
            ("pm.npm", "npm cache", "/.npm/_cacache"),
            ("pm.pnpm", "pnpm store", "/Library/pnpm/store"),
            ("pm.yarn", "Yarn cache", "/Library/Caches/Yarn"),
            ("pm.pip", "pip cache", "/Library/Caches/pip"),
            ("pm.composer", "Composer cache", "/Library/Caches/composer"),
            ("pm.composerLegacy", "Composer cache", "/.composer/cache"),
            ("pm.gradleCaches", "Gradle caches", "/.gradle/caches"),
            ("pm.gradleWrapper", "Gradle wrapper downloads", "/.gradle/wrapper/dists"),
            ("pm.homebrew", "Homebrew downloads", "/Library/Caches/Homebrew"),
            ("pm.cocoapods", "CocoaPods cache", "/Library/Caches/CocoaPods"),
            ("pm.cargoRegistryCache", "Cargo download cache", "/.cargo/registry/cache"),
            ("pm.cargoRegistrySrc", "Cargo extracted sources", "/.cargo/registry/src"),
            ("pm.goBuild", "Go build cache", "/Library/Caches/go-build"),
        ]
        var rules: [any Rule] = safe.map { id, title, suffix in
            LocationRule(
                id: id, title: title, path: home + suffix,
                category: .packageManagerCache, level: .safe,
                reason: "Packages kept so they need not be downloaded again.",
                consequence: "Downloaded again on demand the next time a project needs them."
            )
        }
        rules.append(LocationRule(
            id: "pm.pubCache", title: "Dart and Flutter packages", path: home + "/.pub-cache",
            category: .packageManagerCache, level: .rebuild,
            reason: "Every Dart and Flutter package version ever fetched, plus globally activated tools.",
            consequence: "Run flutter pub get in each project; global tools must be activated again."
        ))
        rules.append(LocationRule(
            id: "pm.playwright", title: "Playwright browsers", path: home + "/Library/Caches/ms-playwright",
            category: .packageManagerCache, level: .rebuild,
            reason: "Browser builds downloaded for Playwright tests.",
            consequence: "Run npx playwright install before running browser tests again."
        ))
        return rules
    }
}
