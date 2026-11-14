import Foundation
import ReclaimCore

// Usage: reclaim-scan [folder]   (default: home folder; pass /System/Volumes/Data for the whole disk)
// Talks to a helper started as a per-user launchd job under a test name, to check pairing without root.
if let index = CommandLine.arguments.firstIndex(of: "--helper-test"), CommandLine.arguments.count > index + 1 {
    let client = HelperClient(machService: CommandLine.arguments[index + 1], privileged: false, helperRequirement: nil)
    do {
        print("version:", try await client.version())
        if let target = CommandLine.arguments.dropFirst(index + 2).first {
            print("remove:", try await client.remove(paths: [target, "/etc/hosts", "/tmp/../etc/hosts"]))
        }
    } catch {
        print("refused:", error.localizedDescription)
    }
    exit(0)
}
if CommandLine.arguments.contains("--print-requirement") {
    print(CodeIdentity.ownRequirement() ?? "none")
    exit(0)
}

if CommandLine.arguments.contains("--docker") {
    let client = DockerClient()
    print("Docker: \(await client.status())")
    let items = try await client.removableItems()
    for kind in [DockerItem.Kind.danglingImage, .unusedImage, .stoppedContainer, .unusedVolume, .buildCache] {
        let some = items.filter { $0.kind == kind }
        let total = some.reduce(Int64(0)) { $0 + $1.size }
        print("  \(kind.title.padding(toLength: 18, withPad: " ", startingAt: 0)) \(some.count) items, \(ByteCountFormatter.string(fromByteCount: total, countStyle: .decimal))")
    }
    // Test of the removal path; only ever touches images named reclaim-test.
    if CommandLine.arguments.contains("--docker-remove-test") {
        let targets = items.filter { $0.kind == .unusedImage && $0.name.hasPrefix("reclaim-test:") }
        print("Removing: \(targets.map(\.name))")
        for outcome in await client.remove(targets) {
            print("  \(outcome.item.title): \(outcome.error ?? "removed")")
        }
    }
    exit(0)
}

let root = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? NSHomeDirectory()
let progress = ScanProgress()
let scanner = DiskScanner(rules: .defaults())
let result = try await scanner.scan(root: root, progress: progress)
let snapshot = progress.snapshot

func size(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }

print("Scanned \(root): \(size(result.root.size)) in \(snapshot.files) files, \(snapshot.folders) folders,"
      + " \(String(format: "%.1f", result.duration)) s, \(result.unreadableFolders) unreadable folders")

let suggestions = result.suggestions()
print("\nBy category:")
for category in SuggestionCategory.allCases {
    let items = suggestions.filter { $0.category == category }
    guard !items.isEmpty else { continue }
    print("  \(category.title.padding(toLength: 32, withPad: " ", startingAt: 0)) \(size(items.reduce(0) { $0 + $1.size }).padding(toLength: 10, withPad: " ", startingAt: 0)) \(items.count) items")
}

print("\nBy rule:")
for (ruleID, items) in Dictionary(grouping: suggestions, by: \.match.ruleID)
    .sorted(by: { $0.value.reduce(0) { $0 + $1.size } > $1.value.reduce(0) { $0 + $1.size } }) {
    print("  \(ruleID.padding(toLength: 32, withPad: " ", startingAt: 0)) \(size(items.reduce(0) { $0 + $1.size }).padding(toLength: 10, withPad: " ", startingAt: 0)) \(items.count) items")
}

let safe = suggestions.filter(\.level.isPreselected)
print("\nPre-ticked (Safe): \(size(safe.reduce(0) { $0 + $1.size })) in \(safe.count) items")
print("\nLargest 15 suggestions:")
for s in suggestions.prefix(15) {
    print("  \(size(s.size).padding(toLength: 10, withPad: " ", startingAt: 0)) \(s.level.title.padding(toLength: 9, withPad: " ", startingAt: 0)) \(s.path)")
}
let large = result.largeFiles()
print("\nLarge files (\(large.count)):")
for s in large.prefix(10) { print("  \(size(s.size).padding(toLength: 10, withPad: " ", startingAt: 0)) \(s.path)") }

if CommandLine.arguments.contains("--leftovers") {
    print("\nLeftovers:")
    for s in suggestions where s.category == .appLeftovers { print("  \(size(s.size).padding(toLength: 10, withPad: " ", startingAt: 0)) \(s.path)") }
}

if CommandLine.arguments.contains("--duplicates") {
    let started = Date()
    let dupProgress = DuplicateProgress()
    let finder = DuplicateFinder()
    let candidates = finder.candidates(in: result.root)
    let groups = try await finder.find(paths: candidates, progress: dupProgress)
    let p = dupProgress.snapshot
    print("\nDuplicates: \(groups.count) groups, \(size(groups.reduce(0) { $0 + $1.reclaimable })) reclaimable;"
          + " \(candidates.count) candidates, \(p.filesRead) reads, \(size(p.bytesRead)) read in"
          + " \(String(format: "%.1f", Date().timeIntervalSince(started))) s")
    let shared = groups.flatMap { g in g.files.filter { g.sharesStorage($0) } }.count
    print("  copies sharing storage with another (APFS clones): \(shared)")
    func abbreviate(_ p: String) -> String { p.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
    for g in groups {
        print("  \(size(g.reclaimable).padding(toLength: 10, withPad: " ", startingAt: 0)) " + g.files.map { abbreviate($0.path) }.joined(separator: "  |  "))
    }
}
