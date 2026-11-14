import Foundation

/// Capacity of the volume holding a path.
public struct VolumeInfo: Sendable, Equatable {
    public let name: String
    public let total: Int64
    /// Free space as Finder reports it, including purgeable space macOS can reclaim on its own.
    public let available: Int64

    public var used: Int64 { total - available }

    public init(name: String, total: Int64, available: Int64) {
        self.name = name
        self.total = total
        self.available = available
    }

    public static func forPath(_ path: String = NSHomeDirectory()) -> VolumeInfo? {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return VolumeInfo(name: values.volumeName ?? "Macintosh HD", total: Int64(total), available: available)
    }
}
