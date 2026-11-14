import Foundation

/// How often scans run on their own while the app is running.
public enum ScanSchedule: String, Codable, Sendable, CaseIterable, Identifiable {
    case off, daily, weekly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "Never"
        case .daily: "Every day"
        case .weekly: "Every week"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .off: nil
        case .daily: 24 * 3600
        case .weekly: 7 * 24 * 3600
        }
    }

    /// When the next scan is due, or nil when scheduling is off. A Mac that never scanned is due at once.
    public func nextRun(after lastRun: Date?, now: Date = Date()) -> Date? {
        guard let interval else { return nil }
        guard let lastRun else { return now }
        return lastRun.addingTimeInterval(interval)
    }

    public func isDue(lastRun: Date?, now: Date = Date()) -> Bool {
        guard let next = nextRun(after: lastRun, now: now) else { return false }
        return next <= now
    }
}

/// Checks the schedule every so often and calls `onDue` when a scan is due. Waking from sleep is covered
/// because each check compares wall-clock dates rather than counting down a timer.
public final class ScanScheduler: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    public init() {}

    deinit { stop() }

    /// - Parameters:
    ///   - checkEvery: how often to look; a minute in the app, much less in tests.
    ///   - schedule: read on every check, so settings changes apply without restarting.
    ///   - lastRun: when the last scan, scheduled or not, finished.
    ///   - onDue: runs the scan; the next check waits until it returns.
    public func start(
        checkEvery: Duration = .seconds(60),
        schedule: @escaping @Sendable () async -> ScanSchedule,
        lastRun: @escaping @Sendable () async -> Date?,
        onDue: @escaping @Sendable () async -> Void
    ) {
        stop()
        let task = Task {
            while !Task.isCancelled {
                if await schedule().isDue(lastRun: await lastRun()) {
                    await onDue()
                }
                try? await Task.sleep(for: checkEvery)
            }
        }
        lock.withLock { self.task = task }
    }

    public func stop() {
        lock.withLock {
            task?.cancel()
            task = nil
        }
    }
}

/// Which Safe items a scheduled scan may delete by itself, when auto-clean is on.
///
/// Only Safe items the user can delete without the helper, and only when nothing inside them changed for
/// `quietPeriod`, so a project being worked on keeps its caches.
public struct AutoCleanPolicy: Sendable {
    public static let defaultQuietPeriod: TimeInterval = 24 * 3600
    public var quietPeriod: TimeInterval

    public init(quietPeriod: TimeInterval = AutoCleanPolicy.defaultQuietPeriod) {
        self.quietPeriod = quietPeriod
    }

    public func items(from suggestions: [Suggestion], now: Date = Date()) -> [Suggestion] {
        let cutoff = now.addingTimeInterval(-quietPeriod)
        return suggestions.filter { $0.level == .safe && $0.isDeletableByUser && $0.modified < cutoff }
    }
}

/// Decides when to warn about low free space: once each time it drops below the threshold.
public struct LowSpaceAlert: Sendable {
    public var threshold: Int64
    private var warned = false

    public init(threshold: Int64) {
        self.threshold = threshold
    }

    /// True when free space has just crossed below the threshold.
    public mutating func shouldWarn(available: Int64) -> Bool {
        if available >= threshold {
            warned = false
            return false
        }
        defer { warned = true }
        return !warned
    }
}
