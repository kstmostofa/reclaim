import Foundation
@testable import ReclaimCore

/// A throwaway folder tree under the system temporary folder, removed when the fixture is released.
final class Fixture {
    let root: String

    init() throws {
        let base = ProtectedPaths.resolve(NSTemporaryDirectory()) ?? NSTemporaryDirectory()
        root = (base as NSString).appendingPathComponent("ReclaimTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(atPath: root)
    }

    func path(_ relative: String) -> String {
        relative.isEmpty ? root : root + "/" + relative
    }

    /// Writes `size` bytes of real data, so every block is allocated.
    @discardableResult
    func file(_ relative: String, size: Int = 10, modified: Date? = nil) throws -> String {
        let full = path(relative)
        try FileManager.default.createDirectory(atPath: (full as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        var data = Data(count: size)
        data.withUnsafeMutableBytes { raw in
            for i in stride(from: 0, to: raw.count, by: 997) { raw[i] = UInt8(truncatingIfNeeded: i) }
        }
        try data.write(to: URL(fileURLWithPath: full))
        if let modified { try touch(relative, modified) }
        return full
    }

    @discardableResult
    func folder(_ relative: String, modified: Date? = nil) throws -> String {
        let full = path(relative)
        try FileManager.default.createDirectory(atPath: full, withIntermediateDirectories: true)
        if let modified { try touch(relative, modified) }
        return full
    }

    /// A file whose logical length is `length` but which occupies almost nothing on disk.
    func sparseFile(_ relative: String, length: Int64) throws {
        let full = path(relative)
        let fd = open(full, O_CREAT | O_WRONLY, 0o644)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        guard ftruncate(fd, off_t(length)) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    func hardLink(_ target: String, _ link: String) throws {
        try FileManager.default.linkItem(atPath: path(target), toPath: path(link))
    }

    func symlink(_ link: String, to destination: String) throws {
        try FileManager.default.createSymbolicLink(atPath: path(link), withDestinationPath: destination)
    }

    func touch(_ relative: String, _ date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: path(relative))
    }

    func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: path(relative))
    }

    /// Allocated bytes as `du` reports them.
    func duBytes(_ relative: String = "") throws -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-s", path(relative)]
        process.environment = ["BLOCKSIZE": "512"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard let blocks = Int64(output.split(whereSeparator: \.isWhitespace).first ?? "") else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return blocks * 512
    }
}

/// An app locator that knows only the identifiers it is given.
struct FakeApps: AppLocating {
    var installed: Set<String> = []

    func isInstalled(bundleID: String) -> Bool { installed.contains(bundleID) }
}

extension DiskScanner {
    /// The default rules with `home` standing in for the user's home folder.
    static func fixture(home: String, custom: [CustomRule] = [], apps: Set<String> = [], now: Date = Date(),
                        options: ScanOptions = ScanOptions()) -> DiskScanner {
        DiskScanner(rules: .defaults(home: home, custom: custom, appLocator: FakeApps(installed: apps), now: now),
                    options: options)
    }
}

extension ScanResult {
    func suggestion(at path: String) -> Suggestion? {
        suggestions().first { $0.path == path }
    }
}
