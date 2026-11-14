import Foundation

/// Runs a command-line program and collects its output. Swapped out in tests.
public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) async throws -> CommandResult
}

public struct CommandResult: Sendable, Equatable {
    public var status: Int32
    public var output: String
    public var error: String

    public init(status: Int32, output: String, error: String = "") {
        self.status = status
        self.output = output
        self.error = error
    }
}

public enum CommandError: Error, LocalizedError {
    case timedOut(String)

    public var errorDescription: String? {
        switch self {
        case .timedOut(let command): "\(command) did not finish in time."
        }
    }
}

/// Runs real processes.
public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            // Apps opened from Finder get a minimal PATH; docker's credential helpers live beside it.
            environment["PATH"] = [(executable as NSString).deletingLastPathComponent, "/usr/local/bin",
                                   "/opt/homebrew/bin", "/usr/bin", "/bin", environment["PATH"] ?? ""].joined(separator: ":")
            process.environment = environment
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            process.standardInput = FileHandle.nullDevice

            let outData = DataBox(), errData = DataBox()
            out.fileHandleForReading.readabilityHandler = { outData.append($0.availableData) }
            err.fileHandleForReading.readabilityHandler = { errData.append($0.availableData) }
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeout)
            let timedOut = DataBox()
            timer.setEventHandler {
                timedOut.append(Data([1]))
                process.terminate()
            }
            process.terminationHandler = { process in
                timer.cancel()
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                outData.append(out.fileHandleForReading.readDataToEndOfFile())
                errData.append(err.fileHandleForReading.readDataToEndOfFile())
                if !timedOut.data.isEmpty {
                    continuation.resume(throwing: CommandError.timedOut(([executable] + arguments).joined(separator: " ")))
                    return
                }
                continuation.resume(returning: CommandResult(
                    status: process.terminationStatus,
                    output: String(decoding: outData.data, as: UTF8.self),
                    error: String(decoding: errData.data, as: UTF8.self)
                ))
            }
            do {
                try process.run()
                timer.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = Data()

    var data: Data { lock.withLock { stored } }

    func append(_ chunk: Data) {
        lock.withLock { stored.append(chunk) }
    }
}

/// Something Docker can remove.
public struct DockerItem: Sendable, Identifiable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case buildCache, danglingImage, unusedImage, stoppedContainer, unusedVolume

        public var level: SafetyLevel {
            switch self {
            case .buildCache, .danglingImage: .safe
            case .unusedImage, .stoppedContainer: .rebuild
            case .unusedVolume: .personal
            }
        }

        public var title: String {
            switch self {
            case .buildCache: "Build cache"
            case .danglingImage: "Dangling image"
            case .unusedImage: "Unused image"
            case .stoppedContainer: "Stopped container"
            case .unusedVolume: "Unused volume"
            }
        }

        public var systemImage: String {
            switch self {
            case .buildCache: "hammer"
            case .danglingImage, .unusedImage: "square.stack.3d.up"
            case .stoppedContainer: "shippingbox"
            case .unusedVolume: "externaldrive"
            }
        }

        public var reason: String {
            switch self {
            case .buildCache: "Layers Docker keeps to speed up later builds. None of it is used by an image right now."
            case .danglingImage: "An untagged image left behind when a newer build took its tag. No container uses it."
            case .unusedImage: "No container, running or stopped, uses this image."
            case .stoppedContainer: "This container is not running."
            case .unusedVolume: "No container uses this volume. Volumes often hold databases and uploaded files."
            }
        }

        public var consequence: String {
            switch self {
            case .buildCache: "The next build runs every step again, so it is slower once."
            case .danglingImage: "Nothing; it has no name and nothing refers to it."
            case .unusedImage: "Pulled or built again the next time something needs it."
            case .stoppedContainer: "Created again from its image when you next run it; changes made inside the container are lost."
            case .unusedVolume: "Its data is gone for good."
            }
        }
    }

    public let kind: Kind
    /// Image or container ID, volume name; empty for the build cache.
    public let reference: String
    public let name: String
    /// Extra detail, such as the image a container was made from.
    public let detail: String
    /// Bytes freed by removing it, as Docker reports them.
    public let size: Int64
    public let created: Date?

    public var id: String { path }
    public var level: SafetyLevel { kind.level }

    /// A stable identifier that never collides with a file path.
    public var path: String { "docker:\(kind.rawValue):\(reference)" }

    public var deletionItem: DeletionItem {
        DeletionItem(path: path, size: size, title: "\(kind.title) \(name)", category: .containers, level: kind.level)
    }
}

/// Finds the Docker command and engine (Docker Desktop, OrbStack, Colima and others), lists what can be
/// removed, and removes it through Docker's own commands. It never touches an engine's disk image.
public struct DockerClient: Sendable {
    public enum Status: Sendable, Equatable {
        case notInstalled
        /// The command exists but no engine answered; the string says why.
        case notRunning(String)
        /// The engine's name, such as "OrbStack" or "Docker Desktop".
        case running(String)
    }

    public static func defaultCandidates(home: String = NSHomeDirectory()) -> [String] {
        ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", home + "/.orbstack/bin/docker",
         "/Applications/OrbStack.app/Contents/MacOS/xbin/docker",
         "/Applications/Docker.app/Contents/Resources/bin/docker", home + "/.docker/bin/docker"]
    }

    public let executable: String?
    let runner: any CommandRunning

    public init(candidates: [String] = DockerClient.defaultCandidates(), runner: any CommandRunning = ProcessRunner()) {
        executable = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        self.runner = runner
    }

    init(executable: String?, runner: any CommandRunning) {
        self.executable = executable
        self.runner = runner
    }

    public func status() async -> Status {
        guard let executable else { return .notInstalled }
        do {
            let result = try await runner.run(executable, ["info", "--format", "{{.Name}}|{{.OperatingSystem}}"], timeout: 15)
            guard result.status == 0 else {
                return .notRunning(Self.firstLine(result.error) ?? "The Docker engine is not running.")
            }
            return .running(Self.engineName(result.output))
        } catch {
            return .notRunning(error.localizedDescription)
        }
    }

    /// Everything that can be removed, largest first.
    public func removableItems() async throws -> [DockerItem] {
        guard let executable else { return [] }
        let result = try await runner.run(executable, ["system", "df", "--verbose", "--format", "json"], timeout: 120)
        guard result.status == 0 else {
            throw DockerError.commandFailed(Self.firstLine(result.error) ?? "docker system df failed.")
        }
        return try Self.parse(diskUsage: result.output)
    }

    /// Removes one item. Returns nil on success, or Docker's reason for refusing.
    public func remove(_ item: DockerItem) async -> String? {
        guard let executable else { return "Docker is not installed." }
        let arguments: [String] = switch item.kind {
        case .buildCache: ["builder", "prune", "--all", "--force"]
        case .danglingImage, .unusedImage: ["image", "rm", item.reference]
        case .stoppedContainer: ["container", "rm", item.reference]
        case .unusedVolume: ["volume", "rm", item.reference]
        }
        do {
            let result = try await runner.run(executable, arguments, timeout: 600)
            return result.status == 0 ? nil : (Self.firstLine(result.error) ?? "Docker refused to remove it.")
        } catch {
            return error.localizedDescription
        }
    }

    /// Removes items one by one, as deletion outcomes for the history.
    public func remove(_ items: [DockerItem], onProgress: @Sendable (DeletionOutcome) -> Void = { _ in }) async -> [DeletionOutcome] {
        var outcomes: [DeletionOutcome] = []
        for item in items {
            if Task.isCancelled { break }
            let outcome = DeletionOutcome(item: item.deletionItem, error: await remove(item))
            outcomes.append(outcome)
            onProgress(outcome)
        }
        return outcomes
    }

    // MARK: Parsing

    static func engineName(_ info: String) -> String {
        let text = info.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        if lower.contains("orbstack") { return "OrbStack" }
        if lower.contains("docker desktop") { return "Docker Desktop" }
        if lower.contains("colima") { return "Colima" }
        if lower.contains("rancher") { return "Rancher Desktop" }
        return text.split(separator: "|").first.map(String.init) ?? "Docker"
    }

    /// Parses `docker system df --verbose --format json`.
    static func parse(diskUsage json: String) throws -> [DockerItem] {
        guard let data = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw DockerError.unreadableOutput }
        func list(_ key: String) -> [[String: Any]] { root.value(key) as? [[String: Any]] ?? [] }

        var items: [DockerItem] = []
        for image in list("Images") where (image.int("Containers") ?? 0) == 0 {
            let repository = image.string("Repository") ?? "<none>"
            let tag = image.string("Tag") ?? "<none>"
            let id = image.string("ID") ?? ""
            guard !id.isEmpty else { continue }
            let dangling = repository == "<none>"
            let size = image.size("UniqueSize") ?? image.size("Size") ?? 0
            items.append(DockerItem(
                kind: dangling ? .danglingImage : .unusedImage, reference: id,
                name: dangling ? Self.shortID(id) : (tag == "<none>" ? repository : "\(repository):\(tag)"),
                detail: "Image \(Self.shortID(id))", size: size, created: image.date("CreatedAt")
            ))
        }
        for container in list("Containers") {
            let state = (container.string("State") ?? "").lowercased()
            guard ["exited", "created", "dead"].contains(state), let id = container.string("ID") else { continue }
            let name = (container.string("Names") ?? Self.shortID(id)).split(separator: ",").first.map(String.init) ?? id
            items.append(DockerItem(
                kind: .stoppedContainer, reference: id, name: name,
                detail: "From \(container.string("Image") ?? "an image") · \(container.string("Status") ?? state)",
                size: container.size("Size") ?? 0, created: container.date("CreatedAt")
            ))
        }
        for volume in list("Volumes") where (volume.int("Links") ?? 0) == 0 {
            guard let name = volume.string("Name") else { continue }
            let anonymous = name.count == 64 && name.allSatisfy(\.isHexDigit)
            items.append(DockerItem(
                kind: .unusedVolume, reference: name, name: anonymous ? Self.shortID(name) : name,
                detail: anonymous ? "Anonymous volume" : "Volume", size: volume.size("Size") ?? 0, created: nil
            ))
        }
        let unusedCache = list("BuildCache").filter { !($0.bool("InUse") ?? false) }
        let cacheSize = unusedCache.reduce(Int64(0)) { $0 + ($1.size("Size") ?? 0) }
        if cacheSize > 0 {
            items.append(DockerItem(
                kind: .buildCache, reference: "", name: "Build cache",
                detail: "\(unusedCache.count) cache records", size: cacheSize,
                created: unusedCache.compactMap { $0.date("LastUsedAt") }.max()
            ))
        }
        return items.sorted { $0.size > $1.size }
    }

    /// Docker's sizes: "1.2GB", "512kB", "0B", "3.5MiB", or "N/A".
    static func parseSize(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let unitStart = trimmed.firstIndex(where: { $0.isLetter }) else { return Int64(Double(trimmed) ?? -1).nonNegative }
        guard let number = Double(trimmed[..<unitStart].trimmingCharacters(in: .whitespaces)) else { return nil }
        let unit = trimmed[unitStart...].lowercased()
        let factor: Double? = switch unit {
        case "b": 1
        case "kb": 1e3
        case "mb": 1e6
        case "gb": 1e9
        case "tb": 1e12
        case "pb": 1e15
        case "kib": 1024
        case "mib": 1_048_576
        case "gib": 1_073_741_824
        case "tib": 1_099_511_627_776
        default: nil
        }
        guard let factor else { return nil }
        return Int64((number * factor).rounded())
    }

    static func shortID(_ id: String) -> String {
        let bare = id.hasPrefix("sha256:") ? String(id.dropFirst(7)) : id
        return String(bare.prefix(12))
    }

    static func firstLine(_ text: String) -> String? {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }
}

public enum DockerError: Error, LocalizedError {
    case commandFailed(String)
    case unreadableOutput

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message
        case .unreadableOutput: "Docker's report could not be read."
        }
    }
}

private extension Int64 {
    var nonNegative: Int64? { self >= 0 ? self : nil }
}

/// Lenient field access: Docker prints some numbers as strings and the casing of keys has varied.
private extension Dictionary where Key == String, Value == Any {
    func value(_ key: String) -> Any? {
        self[key] ?? first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }

    func string(_ key: String) -> String? {
        switch value(key) {
        case let s as String: s
        case let n as NSNumber: n.stringValue
        default: nil
        }
    }

    func int(_ key: String) -> Int? {
        switch value(key) {
        case let n as NSNumber: n.intValue
        case let s as String: Int(s.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    func bool(_ key: String) -> Bool? {
        switch value(key) {
        case let n as NSNumber: n.boolValue
        case let s as String: s.lowercased() == "true"
        default: nil
        }
    }

    func size(_ key: String) -> Int64? {
        switch value(key) {
        case let n as NSNumber: n.int64Value
        case let s as String: DockerClient.parseSize(s)
        default: nil
        }
    }

    func date(_ key: String) -> Date? {
        guard let text = string(key) else { return nil }
        // "2024-05-01 10:20:30 +0200 CEST"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        var parts = text.split(separator: " ").map(String.init)
        // Build cache times carry fractional seconds: "19:26:07.015220959".
        if parts.count >= 2, let dot = parts[1].firstIndex(of: ".") { parts[1] = String(parts[1][..<dot]) }
        if parts.count >= 3, let date = formatter.date(from: parts[0...2].joined(separator: " ")) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}
