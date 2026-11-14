import Foundation
import Testing
@testable import ReclaimCore

/// The helper's rules, exercised without root: a temporary folder stands in for the system folders and home.
@Suite struct HelperPolicyTests {
    func policy(_ fx: Fixture) -> PathPolicy {
        PathPolicy(home: fx.path("home"), systemRoots: [fx.path("syscache")])
    }

    func setUp() throws -> Fixture {
        let fx = try Fixture()
        try fx.file("home/.npm/_cacache/root-owned.bin")
        try fx.file("home/Documents/keep.txt")
        try fx.file("syscache/com.example/data.bin")
        try fx.file("elsewhere/secret.txt")
        return fx
    }

    @Test func allowsInsideSystemFoldersAndHome() throws {
        let fx = try setUp()
        let p = policy(fx)
        #expect(try p.check(fx.path("syscache/com.example")).path == fx.path("syscache/com.example"))
        #expect(try p.check(fx.path("home/.npm/_cacache")).name == "_cacache")
        #expect(try p.check(fx.path("home/Documents/keep.txt")).parent == fx.path("home/Documents"))
    }

    @Test func refusesOutsideRootsAndTheRootsThemselves() throws {
        let fx = try setUp()
        let p = policy(fx)
        #expect(throws: PathPolicy.Refusal.outsideAllowedFolders) { try p.check(fx.path("elsewhere/secret.txt")) }
        #expect(throws: PathPolicy.Refusal.outsideAllowedFolders) { try p.check(fx.path("syscache")) }
        #expect(throws: PathPolicy.Refusal.outsideAllowedFolders) { try p.check("/etc/passwd") }
        #expect(throws: PathPolicy.Refusal.outsideAllowedFolders) { try p.check("/System/Library/CoreServices") }
        #expect(throws: PathPolicy.Refusal.protected) { try p.check(fx.path("home/Documents")) }
    }

    @Test func refusesDotsAndRelativePaths() throws {
        let fx = try setUp()
        let p = policy(fx)
        #expect(throws: PathPolicy.Refusal.relativeComponents) { try p.check(fx.path("syscache/../elsewhere/secret.txt")) }
        #expect(throws: PathPolicy.Refusal.relativeComponents) { try p.check(fx.path("home/./x")) }
        #expect(throws: PathPolicy.Refusal.notAbsolute) { try p.check("home/x") }
        #expect(throws: PathPolicy.Refusal.notAbsolute) { try p.check("/tmp/a\0b") }
        #expect(throws: PathPolicy.Refusal.missingParent) { try p.check(fx.path("home/nope/x")) }
    }

    @Test func refusesSymlinkEscapes() throws {
        let fx = try setUp()
        // A link inside an allowed folder pointing outside it.
        try fx.symlink("home/escape", to: fx.path("elsewhere"))
        try fx.symlink("syscache/etc", to: "/etc")
        let p = policy(fx)
        #expect(throws: PathPolicy.Refusal.outsideAllowedFolders) { try p.check(fx.path("home/escape/secret.txt")) }
        #expect(throws: PathPolicy.Refusal.outsideAllowedFolders) { try p.check(fx.path("syscache/etc/hosts")) }
        // The link itself may go: removing a link never touches its target.
        #expect(try p.check(fx.path("home/escape")).name == "escape")
    }

    @Test func safeRemoverDeletesAndRefusesSwappedParents() throws {
        let fx = try setUp()
        let p = policy(fx)
        let target = try p.check(fx.path("syscache/com.example"))
        #expect(SafeRemover.remove(target) == nil)
        #expect(!fx.exists("syscache/com.example"))

        // Check passes, then the parent folder is swapped for a link before the delete runs.
        try fx.file("home/cache/victim.bin")
        let raced = try p.check(fx.path("home/cache/victim.bin"))
        try FileManager.default.removeItem(atPath: fx.path("home/cache"))
        try fx.symlink("home/cache", to: fx.path("elsewhere"))
        try fx.file("elsewhere/victim.bin")
        #expect(SafeRemover.remove(raced)?.contains("link") == true)
        #expect(fx.exists("elsewhere/victim.bin"))
    }

    @Test func safeRemoverRemovesLinksNotTargets() throws {
        let fx = try setUp()
        try fx.symlink("home/link-to-elsewhere", to: fx.path("elsewhere"))
        let target = try policy(fx).check(fx.path("home/link-to-elsewhere"))
        #expect(SafeRemover.remove(target) == nil)
        #expect(fx.exists("elsewhere/secret.txt"))
    }

    @Test func snapshotDates() {
        #expect(SnapshotDate.isValid("2026-11-14-101500"))
        #expect(!SnapshotDate.isValid("2026-11-14"))
        #expect(!SnapshotDate.isValid("2026-11-14-10150x"))
        #expect(!SnapshotDate.isValid("2026-11-14-101500; rm -rf /"))
        #expect(!SnapshotDate.isValid("２０２６-11-14-101500"))
    }
}
