import Foundation
import ReclaimCore

// Usage: reclaim-scan [folder]   (default: home folder; pass /System/Volumes/Data for the whole disk)
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
