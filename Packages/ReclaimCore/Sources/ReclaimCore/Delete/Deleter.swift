import Darwin
import Foundation

/// One thing to delete, with what the scan measured for it.
public struct DeletionItem: Sendable, Codable, Hashable {
    public var path: String
    public var size: Int64
    public var title: String
    public var category: SuggestionCategory?
    public var level: SafetyLevel?

    public init(path: String, size: Int64, title: String, category: SuggestionCategory? = nil, level: SafetyLevel? = nil) {
        self.path = path
        self.size = size
        self.title = title
        self.category = category
        self.level = level
    }
}

public enum DeletionMode: String, Sendable, Codable {
    /// Removed at once; the space is free immediately.
    case permanent
    /// Moved to the Trash; the space is freed when the Trash is emptied.
    case trash
}

public struct DeletionOutcome: Sendable, Codable, Hashable {
    public var item: DeletionItem
    /// Nil on success.
    public var error: String?

    public init(item: DeletionItem, error: String?) {
        self.item = item
        self.error = error
    }

    public var succeeded: Bool { error == nil }
}

public struct DeletionReport: Sendable, Codable {
    public var startedAt: Date
    public var finishedAt: Date
    public var mode: DeletionMode
    public var outcomes: [DeletionOutcome]

    public var freedBytes: Int64 {
        outcomes.filter(\.succeeded).reduce(0) { $0 + $1.item.size }
    }

    public var failures: [DeletionOutcome] { outcomes.filter { !$0.succeeded } }
}

/// Deletes items one by one, refusing protected paths, and reports each outcome as it happens.
public struct Deleter: Sendable {
    public var mode: DeletionMode
    public var protectedPaths: ProtectedPaths

    public init(mode: DeletionMode = .permanent, protectedPaths: ProtectedPaths = ProtectedPaths()) {
        self.mode = mode
        self.protectedPaths = protectedPaths
    }

    /// Deletes `items` in order. `onProgress` receives the number finished so far and the latest outcome.
    /// Stops early, leaving the rest untouched, if the task is cancelled.
    public func delete(
        _ items: [DeletionItem],
        onProgress: @Sendable (Int, DeletionOutcome) -> Void = { _, _ in }
    ) async -> DeletionReport {
        let started = Date()
        var outcomes: [DeletionOutcome] = []
        for item in items {
            if Task.isCancelled { break }
            let outcome = DeletionOutcome(item: item, error: deleteOne(item.path))
            outcomes.append(outcome)
            onProgress(outcomes.count, outcome)
            await Task.yield()
        }
        return DeletionReport(startedAt: started, finishedAt: Date(), mode: mode, outcomes: outcomes)
    }

    /// The error for items the user may not delete; the app can retry those through the helper.
    public static let permissionDenied = "Permission denied. It may be owned by another user or protected by macOS."

    /// Returns nil on success, or why it failed.
    func deleteOne(_ path: String) -> String? {
        do {
            try protectedPaths.validate(path)
        } catch {
            return error.localizedDescription
        }
        guard EntryStat.lstat(path) != nil else { return "It no longer exists." }
        switch mode {
        case .permanent:
            guard removefile(path, nil, removefile_flags_t(REMOVEFILE_RECURSIVE)) == 0 else {
                let code = errno
                if code == EPERM || code == EACCES { return Self.permissionDenied }
                return String(cString: strerror(code))
            }
            return nil
        case .trash:
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
    }
}
