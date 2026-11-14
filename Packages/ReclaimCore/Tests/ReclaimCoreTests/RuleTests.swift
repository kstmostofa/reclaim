import Foundation
import Testing
@testable import ReclaimCore

@Suite struct RuleTests {
    /// Builds a project tree with one example of every name-based rule, plus look-alikes that must not match.
    @Test func projectRulesMatchTheirFixturesAndNothingElse() async throws {
        let fx = try Fixture()
        try fx.file("web/package.json")
        try fx.file("web/.next/cache/big.pack", size: 50_000)
        try fx.file("web/node_modules/react/index.js", size: 5_000)
        try fx.file("web/node_modules/react/node_modules/inner/index.js")
        try fx.file("web/.turbo/x")
        try fx.file("nuxt/package.json")
        try fx.file("nuxt/.nuxt/x")
        try fx.file("kit/package.json")
        try fx.file("kit/.svelte-kit/x")
        try fx.file("parcel/.parcel-cache/x")
        try fx.file("php/composer.json")
        try fx.file("php/vendor/autoload.php")
        try fx.file("ios/Podfile")
        try fx.file("ios/Pods/x")
        try fx.file("rust/Cargo.toml")
        try fx.file("rust/target/debug/app", size: 10_000)
        try fx.file("flutter/pubspec.yaml")
        try fx.file("flutter/.dart_tool/x")
        try fx.file("py/__pycache__/m.pyc")
        try fx.file("py/.venv/pyvenv.cfg")
        try fx.file("py/.venv/lib/site.py")
        try fx.file("android/build.gradle")
        try fx.file("android/.gradle/x")
        try fx.file("android/app/build/intermediates/dex/classes.dex")
        try fx.file("android/app/build/outputs/apk/app.apk")

        // Look-alikes.
        try fx.file("orphan/node_modules/x")
        try fx.file("orphan/vendor/x")
        try fx.file("orphan/target/x")
        try fx.file("orphan/env/x")
        try fx.file("orphan/intermediates/x")
        try fx.file("orphan/.next")
        try fx.file("home/.vscode/extensions/ext-1.0/package.json")
        try fx.file("home/.vscode/extensions/ext-1.0/node_modules/x")
        try fx.file("home/.composer/composer.json")
        try fx.file("home/.composer/vendor/x")
        try fx.file("home/Library/Application Support/Tool/package.json")
        try fx.file("home/Library/Application Support/Tool/node_modules/x")

        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        let found = Dictionary(uniqueKeysWithValues: result.suggestions().map { ($0.path, $0.match.ruleID) })
        let expected: [String: String] = [
            "web/.next": "build.next",
            "web/node_modules": "deps.nodeModules",
            "web/.turbo": "build.turbo",
            "nuxt/.nuxt": "build.nuxt",
            "kit/.svelte-kit": "build.svelteKit",
            "parcel/.parcel-cache": "build.parcel",
            "php/vendor": "deps.composerVendor",
            "ios/Pods": "deps.pods",
            "rust/target": "build.rustTarget",
            "flutter/.dart_tool": "build.dartTool",
            "py/__pycache__": "build.pycache",
            "py/.venv": "deps.pythonVenv",
            "android/.gradle": "build.gradleProject",
            "android/app/build/intermediates": "build.androidIntermediates",
        ]
        #expect(found == Dictionary(uniqueKeysWithValues: expected.map { (fx.path($0.key), $0.value) }))
        #expect(result.suggestion(at: fx.path("web/node_modules"))?.size == (try fx.duBytes("web/node_modules")))
    }

    @Test func homeLocationRules() async throws {
        let fx = try Fixture()
        let home = "home"
        let old = Date().addingTimeInterval(-200 * 24 * 3600)
        try fx.file("\(home)/.npm/_cacache/index")
        try fx.file("\(home)/.gradle/caches/x")
        try fx.file("\(home)/.pub-cache/hosted/x")
        try fx.file("\(home)/Library/Caches/Homebrew/x")
        try fx.file("\(home)/Library/Caches/ms-playwright/x")
        try fx.file("\(home)/Library/Caches/com.example.App/x")
        try fx.file("\(home)/Library/Logs/DiagnosticReports/a.ips")
        try fx.file("\(home)/Library/Developer/Xcode/DerivedData/App-abc/x")
        try fx.file("\(home)/Library/Developer/Xcode/iOS DeviceSupport/17.0 (21A)/x")
        try fx.file("\(home)/.android/avd/Pixel.avd/config.ini")
        try fx.file("\(home)/.android/avd/Pixel.avd/snapshots/default_boot/ram.bin")
        try fx.file("\(home)/.android/avd/Pixel.avd/userdata-qemu.img")
        try fx.file("\(home)/.Trash/thing.zip")
        try fx.file("\(home)/Downloads/old.dmg", modified: old)
        try fx.file("\(home)/Downloads/new.dmg")
        try fx.file("\(home)/Library/Containers/com.docker.docker/Data/x")
        try fx.file("\(home)/Library/Containers/com.example.Installed/x")
        try fx.file("\(home)/Library/Containers/com.example.Installed.ShareExtension/x")
        try fx.file("\(home)/Library/Containers/com.apple.Notes/x")
        try fx.file("\(home)/Library/Application Support/Some Tool/x")

        let scanner = DiskScanner.fixture(home: fx.path(home), apps: ["com.example.Installed"])
        let result = try await scanner.scan(root: fx.root)
        let found = Dictionary(uniqueKeysWithValues: result.suggestions().map { ($0.path, $0.match.ruleID) })
        let expected: [String: String] = [
            ".npm/_cacache": "pm.npm",
            ".gradle/caches": "pm.gradleCaches",
            ".pub-cache": "pm.pubCache",
            "Library/Caches/Homebrew": "pm.homebrew",
            "Library/Caches/ms-playwright": "pm.playwright",
            "Library/Caches/com.example.App": "app.caches",
            "Library/Logs/DiagnosticReports": "app.logs",
            "Library/Developer/Xcode/DerivedData/App-abc": "build.xcodeDerivedData",
            "Library/Developer/Xcode/iOS DeviceSupport/17.0 (21A)": "mobile.iosDeviceSupport",
            ".android/avd/Pixel.avd/snapshots": "mobile.avdSnapshots",
            ".android/avd/Pixel.avd/userdata-qemu.img": "mobile.avdUserData",
            ".Trash/thing.zip": "trash",
            "Downloads/old.dmg": "downloads.old",
            "Library/Containers/com.docker.docker": "leftovers.appData",
        ]
        #expect(found == Dictionary(uniqueKeysWithValues: expected.map { (fx.path(home + "/" + $0.key), $0.value) }))
    }

    @Test func safetyLevelsDrivePreselection() {
        #expect(SafetyLevel.safe.isPreselected)
        #expect(!SafetyLevel.rebuild.isPreselected)
        #expect(!SafetyLevel.personal.isPreselected)
    }

    @Test func noRulesInsideAppBundles() async throws {
        let fx = try Fixture()
        try fx.file("Tool.app/Contents/Resources/package.json")
        try fx.file("Tool.app/Contents/Resources/node_modules/x")
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        #expect(result.suggestions().isEmpty)
    }

    @Test func bundleIDShape() {
        #expect(LeftoverAppDataRule.looksLikeBundleID("com.docker.docker"))
        #expect(LeftoverAppDataRule.looksLikeBundleID("dev.kdrag0n.MacVirt"))
        #expect(!LeftoverAppDataRule.looksLikeBundleID("Google"))
        #expect(!LeftoverAppDataRule.looksLikeBundleID("Code.app"))
        #expect(!LeftoverAppDataRule.looksLikeBundleID("com..x"))
        #expect(!LeftoverAppDataRule.looksLikeBundleID("my folder.v2.old"))
    }
}

@Suite struct CustomRuleTests {
    let home = "/Users/test"

    func rule(_ pattern: String) -> CustomRule {
        CustomRule(name: "t", pattern: pattern, level: .safe, home: home)
    }

    @Test func globs() {
        let tenant = rule("**/api/storage/tenant*")
        #expect(tenant.matches(path: "/Users/test/Projects/shop/api/storage/tenant42"))
        #expect(tenant.matches(path: "/api/storage/tenant"))
        #expect(!tenant.matches(path: "/Users/test/api/storage/other"))
        #expect(!tenant.matches(path: "/Users/test/api/storage/tenant1/inner"))

        #expect(rule("api/storage/tenant*").matches(path: "/x/y/api/storage/tenant9"))
        #expect(rule("~/Projects/*/tmp").matches(path: "/Users/test/Projects/a/tmp"))
        #expect(!rule("~/Projects/*/tmp").matches(path: "/Users/test/Projects/a/b/tmp"))
        #expect(rule("~/Projects/**/tmp").matches(path: "/Users/test/Projects/a/b/tmp"))
        #expect(rule("/var/log/app?.log").matches(path: "/var/log/app1.log"))
        #expect(!rule("/var/log/app?.log").matches(path: "/var/log/app12.log"))
        #expect(rule("~/a+b (1)/[x]").matches(path: "/Users/test/a+b (1)/[x]"))
        #expect(!rule("").isValid)
    }

    @Test func customRulesWinAndCanBeDisabled() async throws {
        let fx = try Fixture()
        try fx.file("shop/api/storage/tenant1/file.txt")
        try fx.file("shop/package.json")
        try fx.file("shop/node_modules/x")
        var custom = CustomRule(name: "Tenant leak", pattern: "**/storage/tenant*", level: .safe, home: fx.path("home"))
        let deps = CustomRule(name: "All deps", pattern: "**/node_modules", level: .personal, home: fx.path("home"))
        var result = try await DiskScanner.fixture(home: fx.path("home"), custom: [custom, deps]).scan(root: fx.root)
        #expect(result.suggestion(at: fx.path("shop/api/storage/tenant1"))?.match.title == "Tenant leak")
        #expect(result.suggestion(at: fx.path("shop/node_modules"))?.level == .personal)

        custom.isEnabled = false
        result = try await DiskScanner.fixture(home: fx.path("home"), custom: [custom]).scan(root: fx.root)
        #expect(result.suggestion(at: fx.path("shop/api/storage/tenant1")) == nil)
    }

    @Test func codableRoundTrip() throws {
        let original = rule("~/x/**")
        let decoded = try JSONDecoder().decode(CustomRule.self, from: JSONEncoder().encode(original))
        #expect(decoded.id == original.id)
        #expect(decoded.pattern == original.pattern)
        #expect(decoded.isValid)
    }
}
