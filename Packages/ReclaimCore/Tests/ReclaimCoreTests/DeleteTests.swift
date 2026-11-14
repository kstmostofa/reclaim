import Foundation
import Testing
@testable import ReclaimCore

@Suite struct ProtectedPathTests {
    let guardrail = ProtectedPaths(home: NSHomeDirectory())

    @Test(arguments: [
        "/", "/System", "/System/Library", "/System/Library/CoreServices/Finder.app", "/usr", "/usr/bin/ls", "/bin",
        "/sbin", "/Library", "/Applications", "/Users", "/Volumes", "/private", "/private/var", "/var", "/etc",
        "/tmp", "/private/tmp", "/var/folders", "/opt/homebrew", "/usr/local", "/Library/Caches", "/Users/Shared",
        "/Users/someoneelse", "/Volumes/External", "/System/Volumes/Data", "/System/Volumes/Data/Users",
        "/System/Volumes/Data/Applications", "/system", "/USERS", "/Users/", "//Users//",
    ])
    func refusesSystemTargets(_ path: String) {
        #expect(guardrail.isProtected(path))
    }

    @Test func refusesHomeAndItsTopFolders() {
        let home = NSHomeDirectory()
        for path in [home, home + "/Documents", home + "/Desktop", home + "/Downloads", home + "/Library",
                     home + "/Library/Caches", home + "/Library/Application Support", home + "/Pictures",
                     home + "/.Trash", home.uppercased()] {
            #expect(guardrail.isProtected(path), "\(path)")
        }
    }

    @Test func refusesRelativeAndDotPaths() {
        #expect(throws: ProtectedPaths.Refusal.notAbsolute) { try guardrail.validate("Users/x") }
        #expect(throws: ProtectedPaths.Refusal.relativeComponents) { try guardrail.validate("/tmp/a/../../System") }
        #expect(throws: ProtectedPaths.Refusal.relativeComponents) { try guardrail.validate("/Users/./x") }
    }

    @Test func refusesSymlinkEscapes() throws {
        let fx = try Fixture()
        try fx.symlink("root", to: "/")
        try fx.symlink("home", to: NSHomeDirectory())
        #expect(guardrail.isProtected(fx.path("root/System")))
        #expect(guardrail.isProtected(fx.path("root/Users")))
        #expect(guardrail.isProtected(fx.path("home/Documents")))
        // The link itself is fine to delete: removing a symlink never touches its target.
        #expect(!guardrail.isProtected(fx.path("root")))
    }

    @Test func allowsEverythingInside() throws {
        let home = NSHomeDirectory()
        for path in [home + "/Documents/old.zip", home + "/Library/Caches/com.example", home + "/Projects/x/node_modules",
                     "/Library/Caches/com.apple.thing", "/usr/local/Cellar/x", "/private/var/folders/ab/cd",
                     "/System/Volumes/Data/Users/x/y", "/Volumes/External/Projects/x"] {
            #expect(!guardrail.isProtected(path), "\(path)")
        }
    }
}

@Suite struct DeleterTests {
    @Test func deletesFilesAndFoldersAndReports() async throws {
        let fx = try Fixture()
        try fx.file("a/node_modules/x/y.js", size: 4_000)
        try fx.file("b.log", size: 1_000)
        let items = [
            DeletionItem(path: fx.path("a/node_modules"), size: 4_096, title: "deps"),
            DeletionItem(path: fx.path("b.log"), size: 1_024, title: "log"),
            DeletionItem(path: fx.path("missing"), size: 99, title: "gone"),
            DeletionItem(path: "/System", size: 1, title: "nope"),
        ]
        let seen = Counter()
        let report = await Deleter().delete(items) { done, _ in seen.set(done) }
        #expect(!fx.exists("a/node_modules"))
        #expect(!fx.exists("b.log"))
        #expect(fx.exists("a"))
        #expect(report.freedBytes == 4_096 + 1_024)
        #expect(report.failures.map(\.item.title) == ["gone", "nope"])
        #expect(report.failures.allSatisfy { $0.error?.isEmpty == false })
        #expect(seen.value == 4)
    }

    @Test func reportsPermissionFailures() async throws {
        let fx = try Fixture()
        try fx.file("ro/inner/file.txt")
        chmod(fx.path("ro/inner"), 0o555)
        defer { chmod(fx.path("ro/inner"), 0o755) }
        let report = await Deleter().delete([DeletionItem(path: fx.path("ro/inner/file.txt"), size: 10, title: "f")])
        #expect(report.failures.count == 1)
        #expect(fx.exists("ro/inner/file.txt"))
    }

    @Test func deletingASymlinkLeavesTheTarget() async throws {
        let fx = try Fixture()
        try fx.file("real/keep.txt")
        try fx.symlink("link", to: fx.path("real"))
        let report = await Deleter().delete([DeletionItem(path: fx.path("link"), size: 0, title: "l")])
        #expect(report.failures.isEmpty)
        #expect(fx.exists("real/keep.txt"))
    }

    @Test func endToEndScanThenDeleteSafeItems() async throws {
        let fx = try Fixture()
        try fx.file("web/package.json")
        try fx.file("web/src/index.ts")
        try fx.file("web/.next/cache/x", size: 40_000)
        try fx.file("web/node_modules/x", size: 40_000)
        let scan = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        let ticked = scan.suggestions().filter(\.level.isPreselected)
        #expect(ticked.map(\.path) == [fx.path("web/.next")])
        let report = await Deleter().delete(ticked.map(\.deletionItem))
        #expect(report.failures.isEmpty)
        #expect(!fx.exists("web/.next"))
        #expect(fx.exists("web/node_modules/x"))
        #expect(fx.exists("web/src/index.ts"))
    }
}

@Suite struct HistoryLogTests {
    @Test func appendsAndLoadsNewestFirst() throws {
        let fx = try Fixture()
        let log = HistoryLog(fileURL: URL(fileURLWithPath: fx.path("sub/history.jsonl")))
        #expect(log.load().isEmpty)
        let item = DeletionItem(path: "/x", size: 10, title: "x", category: .buildCache, level: .safe)
        let first = DeletionReport(startedAt: Date(timeIntervalSince1970: 1_000), finishedAt: Date(timeIntervalSince1970: 1_001),
                                   mode: .permanent, outcomes: [DeletionOutcome(item: item, error: nil)])
        var second = first
        second.startedAt = Date(timeIntervalSince1970: 2_000)
        second.mode = .trash
        second.outcomes.append(DeletionOutcome(item: item, error: "Permission denied"))
        try log.append(first)
        try log.append(second)
        let loaded = log.load()
        #expect(loaded.count == 2)
        #expect(loaded[0].mode == .trash)
        #expect(loaded[0].failures.count == 1)
        #expect(loaded[1].freedBytes == 10)
        try log.clear()
        #expect(log.load().isEmpty)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    var value: Int { lock.withLock { stored } }

    func set(_ value: Int) { lock.withLock { stored = value } }
}
