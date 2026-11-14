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

    let settings: AppSettings
    private(set) var phase = Phase.idle
    private(set) var progress = ScanProgress.Snapshot()
    private(set) var volume = VolumeInfo.forPath()
    private(set) var result: ScanResult?
    /// The scanned tree, kept up to date as things are deleted.
    private(set) var tree: FileNode?
    private(set) var suggestions: [Suggestion] = []
    private(set) var largeFiles: [Suggestion] = []
    private(set) var scanError: String?
    /// Nil until duplicates are searched for after the current scan.
    private(set) var duplicates: [DuplicateGroup]?
    private(set) var isFindingDuplicates = false
    /// Nil until Docker has been checked.
    private(set) var dockerStatus: DockerClient.Status?
    private(set) var dockerItems: [DockerItem] = []
    private(set) var isLoadingDocker = false
    private(set) var dockerError: String?
    private(set) var duplicateProgress = DuplicateProgress.Snapshot()
    private(set) var runningBundleIDs: Set<String> = []
    private(set) var hasFullDiskAccess = PrivacyAccess.hasFullDiskAccess()
    /// True when the last scan left out folders macOS would have asked about.
    private(set) var lastScanSkippedPrivateFolders = false
    /// Paths ticked for deletion.
    var ticked: Set<String> = []
    /// The suggestion shown in the inspector.
    var inspected: Suggestion?
    var deletion: DeletionRun?

    /// What each tickable path is, whichever screen it was ticked on.
    @ObservationIgnored private var tickable: [String: DeletionItem] = [:]
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var duplicateTask: Task<Void, Never>?
    @ObservationIgnored private let history = HistoryLog()
    @ObservationIgnored private let protectedPaths = ProtectedPaths()
    @ObservationIgnored private let docker = DockerClient()

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: Scanning

    func startScan() {
        guard phase != .scanning else { return }
        scanTask?.cancel()
        phase = .scanning
        scanError = nil
        progress = ScanProgress.Snapshot()
        let tracker = ScanProgress()
        var options = ScanOptions()
        options.excludedPaths = Set(settings.excludedFolders)
        refreshAccess()
        // Without Full Disk Access these folders raise consent dialogs that stall the scan until answered.
        let skipPrivate = !hasFullDiskAccess
        options.excludedPaths.formUnion(skipPrivate ? PrivacyAccess.promptingLocations()
                                                    : PrivacyAccess.alwaysPromptingLocations())
        let scanner = DiskScanner(rules: .defaults(downloadsAgeDays: settings.downloadsAgeDays), options: options)
        let root = settings.scanScope.root
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
                    try await scanner.scan(root: root, progress: tracker)
                }.value
                progress = tracker.snapshot
                lastScanSkippedPrivateFolders = skipPrivate
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
        duplicateTask?.cancel()
        duplicates = nil
        result = scan
        tree = scan.root
        suggestions = scan.suggestions()
        tickable = [:]
        for s in suggestions { tickable[s.path] = s.deletionItem }
        recomputeLargeFiles()
        ticked = settings.preselectSafe ? Set(suggestions.filter(\.level.isPreselected).map(\.path)) : []
        refreshRunningApps()
        volume = VolumeInfo.forPath()
        phase = .scanned
        refreshDocker()
    }

    /// Rebuilds Large Files from the tree, for example after the threshold changes.
    func recomputeLargeFiles() {
        guard let result, let tree else { return }
        largeFiles = ScanResult(root: tree, startedAt: result.startedAt, duration: result.duration,
                                unreadableFolders: result.unreadableFolders)
            .largeFiles(threshold: settings.largeFileThreshold)
        for s in largeFiles { tickable[s.path] = s.deletionItem }
    }

    // MARK: Docker

    /// Checks the Docker engine and lists what it can remove. Newly found Safe items are ticked when
    /// Safe items are ticked after scans.
    func refreshDocker() {
        guard !isLoadingDocker else { return }
        isLoadingDocker = true
        dockerError = nil
        let docker = docker
        Task {
            defer { isLoadingDocker = false }
            let status = await docker.status()
            dockerStatus = status
            guard case .running = status else {
                dockerItems = []
                return
            }
            do {
                let items = try await docker.removableItems()
                let known = Set(dockerItems.map(\.path))
                for item in items { tickable[item.path] = item.deletionItem }
                if settings.preselectSafe {
                    ticked.formUnion(items.filter { $0.level == .safe && !known.contains($0.path) }.map(\.path))
                }
                let current = Set(items.map(\.path))
                ticked = ticked.filter { !$0.hasPrefix("docker:") || current.contains($0) }
                dockerItems = items
            } catch {
                dockerError = error.localizedDescription
            }
        }
    }

    // MARK: Duplicates

    func findDuplicates() {
        guard let tree, !isFindingDuplicates else { return }
        isFindingDuplicates = true
        duplicateProgress = DuplicateProgress.Snapshot()
        let tracker = DuplicateProgress()
        let finder = DuplicateFinder(minimumSize: Int64(settings.duplicateMinimumMB) * 1_000_000)
        duplicateTask = Task {
            let poller = Task {
                while !Task.isCancelled {
                    duplicateProgress = tracker.snapshot
                    try? await Task.sleep(for: .milliseconds(120))
                }
            }
            defer {
                poller.cancel()
                isFindingDuplicates = false
            }
            guard let groups = try? await Task.detached(priority: .userInitiated, operation: {
                try await finder.find(in: tree, progress: tracker)
            }).value else { return }
            duplicateProgress = tracker.snapshot
            for group in groups {
                for file in group.files { tickable[file.path] = group.deletionItem(for: file) }
            }
            duplicates = groups
        }
    }

    func cancelDuplicates() {
        duplicateTask?.cancel()
    }

    /// Ticks every copy except the one `choice` keeps, in each of `groups`. Groups the choice does not
    /// apply to are left as they are.
    func keep(_ choice: KeepChoice, in groups: [DuplicateGroup]) {
        for group in groups {
            let delete = choice.copiesToDelete(in: group)
            guard !delete.isEmpty else { continue }
            ticked.subtract(group.files.map(\.path))
            ticked.formUnion(delete.map(\.path))
        }
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

    /// Everything ticked, leaving out anything inside another ticked folder so nothing is counted twice.
    var tickedItems: [DeletionItem] {
        let items = ticked.compactMap { tickable[$0] }.sorted { $0.path < $1.path }
        var out: [DeletionItem] = []
        for item in items {
            if let last = out.last, item.path.hasPrefix(last.path + "/") { continue }
            out.append(item)
        }
        return out
    }

    var tickedSize: Int64 { tickedItems.reduce(0) { $0 + $1.size } }

    /// True when the item is an app's cache or data and that app is running now.
    func belongsToRunningApp(_ suggestion: Suggestion) -> Bool {
        suggestion.category == .appCache || suggestion.category == .appLeftovers
            ? runningBundleIDs.contains(suggestion.name.lowercased())
            : false
    }

    func refreshAccess() {
        hasFullDiskAccess = PrivacyAccess.hasFullDiskAccess()
    }

    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(PrivacyAccess.settingsURL)
    }

    func refreshRunningApps() {
        runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
    }

    func canDelete(_ path: String) -> Bool {
        !protectedPaths.isProtected(path)
    }

    // MARK: Selection

    func tickAllSafe(in items: [Suggestion]) {
        ticked.formUnion(items.filter { $0.level == .safe }.map(\.path))
    }

    func untick(_ items: [Suggestion]) {
        ticked.subtract(items.map(\.path))
    }

    func untickAll() {
        ticked.removeAll()
    }

    /// Ticks or unticks anything in the disk map.
    func setTicked(_ node: FileNode, _ on: Bool) {
        guard on else {
            ticked.remove(node.path)
            return
        }
        guard canDelete(node.path) else { return }
        if tickable[node.path] == nil {
            tickable[node.path] = DeletionItem(path: node.path, size: node.size, title: node.match?.title ?? node.name,
                                               category: node.match?.category, level: node.match?.level)
        }
        ticked.insert(node.path)
    }

    // MARK: Deleting

    /// Deletes every ticked item at once; no confirmation, by design.
    func deleteTicked() {
        let items = tickedItems
        guard !items.isEmpty, deletion == nil else { return }
        deletion = DeletionRun(total: items.count, current: items[0].path)
        let deleter = Deleter(mode: settings.moveToTrash ? .trash : .permanent)
        // Docker items are removed by Docker; everything else is a file or folder.
        let dockerByPath = Dictionary(uniqueKeysWithValues: dockerItems.map { ($0.path, $0) })
        let dockerItems = items.compactMap { dockerByPath[$0.path] }
        let files = items.filter { dockerByPath[$0.path] == nil }
        let docker = docker
        let history = history
        Task {
            var report = await Task.detached(priority: .userInitiated) {
                await deleter.delete(files) { done, outcome in
                    Task { @MainActor in
                        self.deletion?.done = done
                        self.deletion?.current = outcome.item.path
                    }
                }
            }.value
            report.outcomes += await docker.remove(dockerItems) { outcome in
                Task { @MainActor in
                    self.deletion?.done += 1
                    self.deletion?.current = outcome.item.title
                }
            }
            report.finishedAt = Date()
            try? history.append(report)
            finish(report)
            if !dockerItems.isEmpty { refreshDocker() }
        }
    }

    private func finish(_ report: DeletionReport) {
        // A file that failed but is no longer there is gone all the same; Docker items have no file to check.
        let gone = Set(report.outcomes.filter {
            $0.succeeded || ($0.item.path.hasPrefix("/") && !FileManager.default.fileExists(atPath: $0.item.path))
        }.map(\.item.path))
        func isGone(_ path: String) -> Bool {
            gone.contains(path) || gone.contains { path.hasPrefix($0 + "/") }
        }
        suggestions.removeAll { isGone($0.path) }
        largeFiles.removeAll { isGone($0.path) }
        duplicates = duplicates?.compactMap { group in
            let left = group.files.filter { !isGone($0.path) }
            return left.count > 1 ? DuplicateGroup(hash: group.hash, size: group.size, files: left) : nil
        }
        dockerItems.removeAll { gone.contains($0.path) }
        ticked = ticked.filter { !isGone($0) }
        tree = tree?.removing(gone)
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
