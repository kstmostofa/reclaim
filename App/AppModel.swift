import AppKit
import Observation
import ReclaimCore

/// The app's state: the last scan, what is ticked, and any deletion in progress.
@MainActor @Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case scanned
    }

    struct DeletionRun {
        var total: Int
        var done = 0
        var current = ""
        var report: DeletionReport?
    }

    private(set) var phase = Phase.idle
    private(set) var progress = ScanProgress.Snapshot()
    private(set) var volume = VolumeInfo.forPath()
    private(set) var result: ScanResult?
    private(set) var suggestions: [Suggestion] = []
    private(set) var scanError: String?
    private(set) var runningBundleIDs: Set<String> = []
    /// Paths ticked for deletion.
    var ticked: Set<String> = []
    var deletion: DeletionRun?

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private let history = HistoryLog()

    /// The whole data volume; paths are still reported as /Users/… and so on.
    static let scanRoot = DiskScanner.dataVolumePath

    var moveToTrash: Bool {
        get { access(keyPath: \.moveToTrash); return UserDefaults.standard.bool(forKey: "moveToTrash") }
        set { withMutation(keyPath: \.moveToTrash) { UserDefaults.standard.set(newValue, forKey: "moveToTrash") } }
    }

    // MARK: Scanning

    func startScan() {
        guard phase != .scanning else { return }
        scanTask?.cancel()
        phase = .scanning
        scanError = nil
        progress = ScanProgress.Snapshot()
        let tracker = ScanProgress()
        let scanner = DiskScanner(rules: .defaults())
        scanTask = Task {
            let poller = Task {
                while !Task.isCancelled {
                    progress = tracker.snapshot
                    try? await Task.sleep(for: .milliseconds(120))
                }
            }
            defer { poller.cancel() }
            do {
                let scan = try await Task.detached(priority: .userInitiated) {
                    try await scanner.scan(root: Self.scanRoot, progress: tracker)
                }.value
                progress = tracker.snapshot
                apply(scan)
            } catch is CancellationError {
                phase = result == nil ? .idle : .scanned
            } catch {
                scanError = error.localizedDescription
                phase = result == nil ? .idle : .scanned
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    private func apply(_ scan: ScanResult) {
        result = scan
        suggestions = scan.suggestions()
        ticked = Set(suggestions.filter(\.level.isPreselected).map(\.path))
        refreshRunningApps()
        volume = VolumeInfo.forPath()
        phase = .scanned
    }

    // MARK: Queries

    func suggestions(in category: SuggestionCategory) -> [Suggestion] {
        suggestions.filter { $0.category == category }
    }

    func total(of items: some Sequence<Suggestion>) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    /// Categories that have anything in them, largest first.
    var categories: [(category: SuggestionCategory, size: Int64, count: Int)] {
        Dictionary(grouping: suggestions, by: \.category)
            .map { ($0.key, total(of: $0.value), $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var reclaimable: Int64 { total(of: suggestions) }
    var safeReclaimable: Int64 { total(of: suggestions.filter { $0.level == .safe }) }

    var tickedSuggestions: [Suggestion] { suggestions.filter { ticked.contains($0.path) } }
    var tickedSize: Int64 { total(of: tickedSuggestions) }

    /// True when the item is an app's cache or data and that app is running now.
    func belongsToRunningApp(_ suggestion: Suggestion) -> Bool {
        suggestion.category == .appCache || suggestion.category == .appLeftovers
            ? runningBundleIDs.contains(suggestion.name.lowercased())
            : false
    }

    func refreshRunningApps() {
        runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
    }

    // MARK: Selection

    func tickAllSafe(in category: SuggestionCategory? = nil) {
        for s in suggestions where s.level == .safe && (category == nil || s.category == category) {
            ticked.insert(s.path)
        }
    }

    func untickAll(in category: SuggestionCategory? = nil) {
        if let category {
            ticked.subtract(suggestions(in: category).map(\.path))
        } else {
            ticked.removeAll()
        }
    }

    // MARK: Deleting

    /// Deletes every ticked item at once; no confirmation, by design.
    func deleteTicked() {
        let items = tickedSuggestions.map(\.deletionItem)
        guard !items.isEmpty, deletion == nil else { return }
        deletion = DeletionRun(total: items.count, current: items[0].path)
        let deleter = Deleter(mode: moveToTrash ? .trash : .permanent)
        let history = history
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                await deleter.delete(items) { done, outcome in
                    Task { @MainActor in
                        self.deletion?.done = done
                        self.deletion?.current = outcome.item.path
                    }
                }
            }.value
            try? history.append(report)
            finish(report)
        }
    }

    private func finish(_ report: DeletionReport) {
        let gone = Set(report.outcomes.filter { $0.succeeded || !FileManager.default.fileExists(atPath: $0.item.path) }
            .map(\.item.path))
        suggestions.removeAll { gone.contains($0.path) }
        ticked.subtract(gone)
        volume = VolumeInfo.forPath()
        deletion?.done = report.outcomes.count
        deletion?.report = report
    }

    func dismissDeletion() {
        deletion = nil
    }

    // MARK: Finder

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

enum Format {
    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func count(_ n: Int) -> String {
        n.formatted(.number)
    }
}
