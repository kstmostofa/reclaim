import Foundation

/// Every deletion run, appended as one JSON line per run.
public struct HistoryLog: Sendable {
    public let fileURL: URL

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reclaim", isDirectory: true)
            .appendingPathComponent("history.jsonl")
    }

    public init(fileURL: URL = HistoryLog.defaultURL) {
        self.fileURL = fileURL
    }

    public func append(_ report: DeletionReport) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var line = try encoder.encode(report)
        line.append(0x0A)
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: fileURL.path) {
            try line.write(to: fileURL, options: .atomic)
            return
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    /// All runs, newest first. Lines that cannot be read are skipped.
    public func load() -> [DeletionReport] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return data.split(separator: 0x0A)
            .compactMap { try? decoder.decode(DeletionReport.self, from: Data($0)) }
            .reversed()
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
