import Foundation
import Testing
@testable import ReclaimCore

@Suite struct DuplicateTests {
    let finder: DuplicateFinder = {
        var f = DuplicateFinder(minimumSize: 100_000, skippedPrefixes: [])
        f.parallelReads = 3
        return f
    }()

    func copy(_ fx: Fixture, _ from: String, _ to: String, clone: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/cp")
        process.arguments = (clone ? ["-c"] : []) + [fx.path(from), fx.path(to)]
        try process.run()
        process.waitUntilExit()
    }

    @Test func findsIdenticalFilesOnly() async throws {
        let fx = try Fixture()
        try fx.file("a/photo.jpg", size: 300_000)
        try fx.folder("b")
        try copy(fx, "a/photo.jpg", "b/photo copy.jpg")
        try copy(fx, "a/photo.jpg", "b/third.jpg")
        // Same size, same first and last 64 KB, different middle: only the full hash tells them apart.
        try fx.file("c/one.bin", size: 400_000)
        try fx.folder("d")
        try copy(fx, "c/one.bin", "d/two.bin")
        var data = try Data(contentsOf: URL(fileURLWithPath: fx.path("d/two.bin")))
        data[200_000] ^= 0xFF
        try data.write(to: URL(fileURLWithPath: fx.path("d/two.bin")))
        // Hard links are one file, not two.
        try fx.file("e/big.bin", size: 500_000)
        try fx.hardLink("e/big.bin", "e/link.bin")
        // Too small to consider.
        try fx.file("f/small.txt", size: 10)
        try copy(fx, "f/small.txt", "f/small2.txt")

        let paths = ["a/photo.jpg", "b/photo copy.jpg", "b/third.jpg", "c/one.bin", "d/two.bin",
                     "e/big.bin", "e/link.bin", "f/small.txt", "f/small2.txt"].map(fx.path)
        let groups = try await finder.find(paths: paths)
        #expect(groups.count == 1)
        let group = try #require(groups.first)
        #expect(Set(group.files.map(\.path)) == Set(["a/photo.jpg", "b/photo copy.jpg", "b/third.jpg"].map(fx.path)))
        #expect(group.size == 300_000)
        #expect(group.reclaimable == 600_000)
    }

    @Test func clonesShareStorageAndFreeNothing() async throws {
        let fx = try Fixture()
        try fx.file("orig.mov", size: 1_000_000)
        try copy(fx, "orig.mov", "clone.mov", clone: true)
        try copy(fx, "orig.mov", "real-copy.mov")
        let group = try #require(try await finder.find(paths: ["orig.mov", "clone.mov", "real-copy.mov"].map(fx.path)).first)
        let clone = try #require(group.files.first { $0.name == "clone.mov" })
        let real = try #require(group.files.first { $0.name == "real-copy.mov" })
        #expect(group.sharesStorage(clone))
        #expect(!group.sharesStorage(real))
        #expect(group.distinctStorage == 2)
        #expect(group.reclaimable == 1_000_000)
        #expect(group.deletionItem(for: clone).size == 0)
    }

    @Test func candidatesSkipBundlesRulesAndSkippedFolders() async throws {
        let fx = try Fixture()
        try fx.file("docs/a.bin", size: 2_000_000)
        try fx.file("Some.app/Contents/a.bin", size: 2_000_000)
        try fx.file("web/package.json")
        try fx.file("web/node_modules/a.bin", size: 2_000_000)
        try fx.file("skip/a.bin", size: 2_000_000)
        try fx.file(".vscode/extensions/x/a.bin", size: 2_000_000)
        try fx.file("tool/lib/python3/site-packages/a.bin", size: 2_000_000)
        try fx.file("orphan/node_modules/a.bin", size: 2_000_000)
        let tree = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root).root
        let finder = DuplicateFinder(minimumSize: 1 << 20, skippedPrefixes: [fx.path("skip") + "/"])
        #expect(finder.candidates(in: tree) == [fx.path("docs/a.bin")])
    }

    @Test func keepChoices() {
        let old = DuplicateFile(path: "/x/keep/a", size: 1, modified: Date(timeIntervalSince1970: 1), storageKey: nil)
        let mid = DuplicateFile(path: "/x/b", size: 1, modified: Date(timeIntervalSince1970: 2), storageKey: nil)
        let new = DuplicateFile(path: "/y/c", size: 1, modified: Date(timeIntervalSince1970: 3), storageKey: nil)
        let group = DuplicateGroup(hash: "h", size: 1, files: [old, mid, new])
        #expect(KeepChoice.oldest.copiesToDelete(in: group).map(\.path) == ["/x/b", "/y/c"])
        #expect(KeepChoice.newest.copiesToDelete(in: group).map(\.path) == ["/x/keep/a", "/x/b"])
        #expect(KeepChoice.inFolder("/y").copiesToDelete(in: group).map(\.path) == ["/x/keep/a", "/x/b"])
        #expect(KeepChoice.inFolder("/x/ke").copiesToDelete(in: group).isEmpty)
    }
}
