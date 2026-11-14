import Foundation
import Testing
@testable import ReclaimCore

@Suite struct ScannerTests {
    @Test func totalMatchesDu() async throws {
        let fx = try Fixture()
        try fx.file("a.bin", size: 1_000_000)
        try fx.file("small/one.txt", size: 100)
        try fx.file("small/two.txt", size: 5_000)
        try fx.file("deep/er/still/deeper/x.bin", size: 300_000)
        try fx.folder("empty")
        try fx.symlink("link", to: "/System")
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        #expect(result.root.size == (try fx.duBytes()))
        #expect(result.root.fileCount == 5)
    }

    @Test func sparseFileCountsAllocatedBytes() async throws {
        let fx = try Fixture()
        try fx.sparseFile("disk.raw", length: 4_000_000_000)
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        #expect(result.root.size < 1_000_000)
        #expect(result.root.size == (try fx.duBytes()))
    }

    @Test func hardLinksCountOnce() async throws {
        let fx = try Fixture()
        try fx.file("one/original.bin", size: 2_000_000)
        try fx.hardLink("one/original.bin", "one/copy.bin")
        try fx.folder("two")
        try fx.hardLink("one/original.bin", "two/third.bin")
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        #expect(result.root.size == (try fx.duBytes()))
        #expect(result.root.size < 3_000_000)
    }

    @Test func sizeMeasurerMatchesDu() throws {
        let fx = try Fixture()
        try fx.file("x/a.bin", size: 123_456)
        try fx.file("x/y/b.bin", size: 7)
        try fx.hardLink("x/a.bin", "x/y/a-again.bin")
        #expect(SizeMeasurer.allocatedSize(of: fx.path("x")) == (try fx.duBytes("x")))
    }

    @Test func keepsLargeFilesAndFoldersInTree() async throws {
        let fx = try Fixture()
        try fx.file("big.bin", size: 2_000_000)
        try fx.file("tiny.txt", size: 10)
        try fx.folder("sub")
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        let names = Set(result.root.children.map(\.name))
        #expect(names == ["big.bin", "sub"])
        #expect(result.root.otherFilesSize > 0)
        #expect(result.root.children.first?.name == "big.bin")
    }

    @Test func unreadableFolderIsFlagged() async throws {
        let fx = try Fixture()
        try fx.file("locked/secret.txt", size: 10)
        chmod(fx.path("locked"), 0o000)
        defer { chmod(fx.path("locked"), 0o755) }
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        #expect(result.unreadableFolders == 1)
        #expect(result.root.node(at: fx.path("locked"))?.isUnreadable == true)
    }

    @Test func largeFilesSkipsCoveredAndBundles() async throws {
        let fx = try Fixture()
        try fx.file("movies/film.mov", size: 3_000_000)
        try fx.file("Some.app/Contents/Resources/huge.dat", size: 3_000_000)
        try fx.file("web/package.json")
        try fx.file("web/node_modules/pkg/blob.bin", size: 3_000_000)
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        let large = result.largeFiles(threshold: 2_000_000).map(\.path)
        #expect(large == [fx.path("movies/film.mov")])
    }

    @Test func excludedPathsAreSkipped() async throws {
        let fx = try Fixture()
        try fx.file("keep/a.bin", size: 50_000)
        try fx.file("skip/b.bin", size: 50_000)
        var options = ScanOptions()
        options.excludedPaths = [fx.path("skip")]
        let result = try await DiskScanner.fixture(home: fx.path("home"), options: options).scan(root: fx.root)
        #expect(result.root.node(at: fx.path("skip")) == nil)
        #expect(result.root.size < (try fx.duBytes()))
    }

    @Test func progressCountsEverything() async throws {
        let fx = try Fixture()
        for i in 0..<20 { try fx.file("d\(i % 4)/f\(i).txt") }
        let progress = ScanProgress()
        let result = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root, progress: progress)
        #expect(progress.snapshot.files == 20)
        #expect(progress.snapshot.folders == 5)
        #expect(progress.snapshot.bytes == result.root.size)
    }

    @Test func cancellationThrows() async throws {
        let fx = try Fixture()
        for i in 0..<200 { try fx.file("d\(i)/f.txt") }
        let scanner = DiskScanner.fixture(home: fx.path("home"))
        let task = Task { try await scanner.scan(root: fx.root) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func dataVolumePathsAreShownInFamiliarForm() async throws {
        // /System/Volumes/Data/Users and /Users are the same folder on every current macOS.
        let paths = try await DiskScanner(rules: RuleSet([])).scanShallow(root: DiskScanner.dataVolumePath, only: "Users")
        #expect(paths == ["/Users"])
    }
}

extension DiskScanner {
    /// Scans `root` with every top-level entry except `only` excluded, and nothing below `only`'s children,
    /// then returns the paths of root's children.
    func scanShallow(root: String, only: String) async throws -> [String] {
        let listing = try #require(DirectoryListing(path: root))
        var options = self.options
        options.excludedPaths = Set(listing.entries.map { root + "/" + $0.name }).subtracting([root + "/" + only])
        for child in DirectoryListing(path: root + "/" + only)?.entries ?? [] {
            options.excludedPaths.insert("/" + only + "/" + child.name)
        }
        let result = try await DiskScanner(rules: rules, options: options).scan(root: root)
        return result.root.children.map(\.path)
    }
}

@Suite struct TreeTests {
    @Test func removingShrinksAncestorsAndSharesTheRest() async throws {
        let fx = try Fixture()
        try fx.file("a/b/big.bin", size: 2_000_000)
        try fx.file("a/b/c/x.txt", size: 50_000)
        try fx.file("other/y.txt", size: 50_000)
        let tree = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root).root
        let b = try #require(tree.node(at: fx.path("a/b")))
        let c = try #require(tree.node(at: fx.path("a/b/c")))
        let big = try #require(tree.node(at: fx.path("a/b/big.bin")))

        let pruned = try #require(tree.removing([big.path, c.path]))
        #expect(pruned.size == tree.size - big.size - c.size)
        #expect(pruned.fileCount == tree.fileCount - 2)
        #expect(pruned.node(at: fx.path("a/b"))?.size == b.size - big.size - c.size)
        #expect(pruned.node(at: c.path) == nil)
        #expect(pruned.node(at: fx.path("other")) === tree.node(at: fx.path("other")))
        #expect(tree.removing([]) === tree)
        #expect(tree.removing([tree.path]) == nil)
    }

    @Test func downloadsAgeIsConfigurable() async throws {
        let fx = try Fixture()
        try fx.file("home/Downloads/month-old.zip", modified: Date().addingTimeInterval(-40 * 24 * 3600))
        let scan = { (days: Int) in
            try await DiskScanner(rules: .defaults(home: fx.path("home"), appLocator: FakeApps(), downloadsAgeDays: days))
                .scan(root: fx.root).suggestions().count
        }
        #expect(try await scan(90) == 0)
        #expect(try await scan(30) == 1)
    }
}

@Suite struct PrivacyAccessTests {
    @Test func missingProbesDoNotCountAsDenied() throws {
        let fx = try Fixture()
        try fx.folder("open")
        try fx.folder("locked")
        chmod(fx.path("locked"), 0o000)
        defer { chmod(fx.path("locked"), 0o755) }
        #expect(PrivacyAccess.hasFullDiskAccess(probes: [fx.path("missing"), fx.path("open")]))
        #expect(!PrivacyAccess.hasFullDiskAccess(probes: [fx.path("missing"), fx.path("locked"), fx.path("open")]))
        #expect(PrivacyAccess.hasFullDiskAccess(probes: [fx.path("missing")]))
    }

    @Test func mediaLibrariesAreAlwaysSkipped() {
        let always = Set(PrivacyAccess.alwaysPromptingLocations(home: "/Users/x"))
        #expect(always.contains("/Users/x/Music/Music"))
        #expect(always.isSubset(of: PrivacyAccess.promptingLocations(home: "/Users/x")))
    }
}
