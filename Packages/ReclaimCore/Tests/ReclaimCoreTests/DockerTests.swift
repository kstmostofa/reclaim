import Foundation
import Testing
@testable import ReclaimCore

/// Answers docker commands from a script and records what was run.
final class FakeDocker: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [[String]] = []
    let answers: [String: CommandResult]

    init(_ answers: [String: CommandResult]) {
        self.answers = answers
    }

    var ran: [[String]] { lock.withLock { calls } }

    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        lock.withLock { calls.append(arguments) }
        return answers[arguments.prefix(2).joined(separator: " ")] ?? CommandResult(status: 1, output: "", error: "unexpected")
    }
}

@Suite struct DockerTests {
    /// Shaped like `docker system df --verbose --format json` from Docker 29.
    static let sample = """
    {"Images":[
      {"Containers":"0","CreatedAt":"2026-10-01 09:00:00 +0200 CEST","ID":"sha256:aaaaaaaaaaaa1111","Repository":"<none>","Tag":"<none>","Size":"300MB","SharedSize":"0B","UniqueSize":"250MB"},
      {"Containers":"0","CreatedAt":"2026-09-01 09:00:00 +0200 CEST","ID":"sha256:bbbbbbbbbbbb2222","Repository":"postgres","Tag":"16","Size":"450MB","UniqueSize":"1.2GB"},
      {"Containers":"2","CreatedAt":"2026-09-01 09:00:00 +0200 CEST","ID":"sha256:cccccccccccc3333","Repository":"redis","Tag":"7","Size":"40MB","UniqueSize":"40MB"}
    ],
    "Containers":[
      {"ID":"c1c1c1c1c1c1","Image":"redis:7","Names":"cache","State":"running","Status":"Up 2 hours","Size":"1kB","CreatedAt":"2026-11-01 10:00:00 +0100 CET"},
      {"ID":"c2c2c2c2c2c2","Image":"redis:7","Names":"old-cache","State":"exited","Status":"Exited (0) 3 days ago","Size":"12.5MB","CreatedAt":"2026-10-20 10:00:00 +0200 CEST"}
    ],
    "Volumes":[
      {"Name":"shop_db","Links":"0","Size":"2.5GB","Driver":"local"},
      {"Name":"live_db","Links":"1","Size":"9GB","Driver":"local"},
      {"Name":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","Links":"0","Size":"N/A"}
    ],
    "BuildCache":[
      {"ID":"x1","InUse":false,"Size":"100MB","LastUsedAt":"2026-11-11 20:22:15.82193 +0000 UTC"},
      {"ID":"x2","InUse":true,"Size":"999MB"},
      {"ID":"x3","InUse":"false","Size":"50MB"}
    ]}
    """

    @Test func parsesAndClassifies() throws {
        let items = try DockerClient.parse(diskUsage: Self.sample)
        let byPath = Dictionary(uniqueKeysWithValues: items.map { ($0.path, $0) })
        #expect(items.count == 6)
        #expect(byPath["docker:danglingImage:sha256:aaaaaaaaaaaa1111"]?.size == 250_000_000)
        #expect(byPath["docker:danglingImage:sha256:aaaaaaaaaaaa1111"]?.name == "aaaaaaaaaaaa")
        #expect(byPath["docker:unusedImage:sha256:bbbbbbbbbbbb2222"]?.name == "postgres:16")
        #expect(byPath["docker:stoppedContainer:c2c2c2c2c2c2"]?.name == "old-cache")
        #expect(byPath["docker:unusedVolume:shop_db"]?.level == .personal)
        #expect(byPath["docker:buildCache:"]?.size == 150_000_000)
        #expect(byPath["docker:buildCache:"]?.level == .safe)
        // In use: never listed.
        #expect(!items.contains { $0.name.hasPrefix("redis") || $0.name == "cache" || $0.name == "live_db" })
        #expect(items.first?.name == "shop_db")
        #expect(byPath["docker:stoppedContainer:c2c2c2c2c2c2"]?.created != nil)
        #expect(byPath["docker:buildCache:"]?.created == Date(timeIntervalSince1970: 1_794_428_535))
    }

    @Test func sizes() {
        #expect(DockerClient.parseSize("0B") == 0)
        #expect(DockerClient.parseSize("512kB") == 512_000)
        #expect(DockerClient.parseSize("1.25GB") == 1_250_000_000)
        #expect(DockerClient.parseSize("3MiB") == 3_145_728)
        #expect(DockerClient.parseSize("N/A") == nil)
        #expect(DockerClient.parseSize("1234") == 1234)
    }

    @Test func statusAndEngineName() async {
        let running = DockerClient(executable: "/x/docker", runner: FakeDocker(["info --format": CommandResult(status: 0, output: "orbstack|OrbStack\n")]))
        #expect(await running.status() == .running("OrbStack"))
        let desktop = DockerClient(executable: "/x/docker", runner: FakeDocker(["info --format": CommandResult(status: 0, output: "docker-desktop|Docker Desktop\n")]))
        #expect(await desktop.status() == .running("Docker Desktop"))
        let stopped = DockerClient(executable: "/x/docker", runner: FakeDocker(["info --format": CommandResult(status: 1, output: "", error: "\nCannot connect to the Docker daemon\n")]))
        #expect(await stopped.status() == .notRunning("Cannot connect to the Docker daemon"))
        #expect(await DockerClient(executable: nil, runner: FakeDocker([:])).status() == .notInstalled)
    }

    @Test func removesThroughDockerCommands() async throws {
        let fake = FakeDocker([
            "system df": CommandResult(status: 0, output: Self.sample),
            "image rm": CommandResult(status: 0, output: "Deleted"),
            "container rm": CommandResult(status: 0, output: "ok"),
            "volume rm": CommandResult(status: 1, output: "", error: "Error: volume is in use"),
            "builder prune": CommandResult(status: 0, output: "Total: 150MB"),
        ])
        let client = DockerClient(executable: "/x/docker", runner: fake)
        let items = try await client.removableItems()
        let outcomes = await client.remove(items)
        #expect(outcomes.count == items.count)
        #expect(outcomes.filter { !$0.succeeded }.map(\.item.title) == ["Unused volume shop_db", "Unused volume 0123456789ab"])
        #expect(outcomes.first { !$0.succeeded }?.error == "Error: volume is in use")
        let ran = fake.ran.dropFirst()
        #expect(ran.contains(["image", "rm", "sha256:bbbbbbbbbbbb2222"]))
        #expect(ran.contains(["container", "rm", "c2c2c2c2c2c2"]))
        #expect(ran.contains(["builder", "prune", "--all", "--force"]))
        // Never forced: Docker itself refuses anything in use.
        #expect(!ran.contains { $0.contains("-f") && !$0.contains("builder") })
    }

    @Test func processRunnerCapturesAndTimesOut() async throws {
        let result = try await ProcessRunner().run("/bin/sh", ["-c", "echo out; echo err >&2; exit 3"], timeout: 10)
        #expect(result == CommandResult(status: 3, output: "out\n", error: "err\n"))
        await #expect(throws: CommandError.self) {
            try await ProcessRunner().run("/bin/sleep", ["5"], timeout: 0.3)
        }
    }
}
