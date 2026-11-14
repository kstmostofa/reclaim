import Foundation
import Testing
@testable import ReclaimCore

@Suite struct ScheduleTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func dueTimes() {
        #expect(ScanSchedule.off.nextRun(after: nil, now: now) == nil)
        #expect(!ScanSchedule.off.isDue(lastRun: nil, now: now))
        #expect(ScanSchedule.daily.isDue(lastRun: nil, now: now))
        #expect(!ScanSchedule.daily.isDue(lastRun: now.addingTimeInterval(-23 * 3600), now: now))
        #expect(ScanSchedule.daily.isDue(lastRun: now.addingTimeInterval(-24 * 3600), now: now))
        #expect(!ScanSchedule.weekly.isDue(lastRun: now.addingTimeInterval(-6 * 24 * 3600), now: now))
        #expect(ScanSchedule.weekly.nextRun(after: now, now: now) == now.addingTimeInterval(7 * 24 * 3600))
    }

    /// A scheduler with a short check interval runs the scan when due and records it, then waits.
    @Test func schedulerTriggersWhenDue() async throws {
        let state = SchedulerState()
        let scheduler = ScanScheduler()
        scheduler.start(
            checkEvery: .milliseconds(20),
            schedule: { .daily },
            lastRun: { await state.lastRun },
            onDue: { await state.ran() }
        )
        try await Task.sleep(for: .milliseconds(300))
        scheduler.stop()
        // Due once at start (never scanned); after that the last run is now, so not due for a day.
        #expect(await state.runs == 1)
    }

    @Test func schedulerDoesNothingWhenOff() async throws {
        let state = SchedulerState()
        let scheduler = ScanScheduler()
        scheduler.start(checkEvery: .milliseconds(20), schedule: { .off }, lastRun: { nil }, onDue: { await state.ran() })
        try await Task.sleep(for: .milliseconds(150))
        scheduler.stop()
        #expect(await state.runs == 0)
    }

    /// Auto-clean on a real scan: a cache touched within 24 hours is skipped, an older one is taken,
    /// and Rebuild items are never taken.
    @Test func autoCleanSkipsRecentlyTouchedFolders() async throws {
        let fx = try Fixture()
        let old = Date().addingTimeInterval(-3 * 24 * 3600)
        try fx.file("idle/package.json", modified: old)
        try fx.file("idle/.next/cache/a.pack", size: 20_000, modified: old)
        try fx.touch("idle/.next/cache", old)
        try fx.touch("idle/.next", old)
        try fx.file("busy/package.json")
        try fx.file("busy/.next/cache/a.pack", size: 20_000, modified: old)
        try fx.file("busy/.next/cache/fresh.pack", size: 20_000)
        try fx.file("idle/node_modules/x", modified: old)
        let scan = try await DiskScanner.fixture(home: fx.path("home")).scan(root: fx.root)
        let picked = AutoCleanPolicy().items(from: scan.suggestions()).map(\.path)
        #expect(picked == [fx.path("idle/.next")])
    }

    @Test func lowSpaceWarnsOncePerCrossing() {
        var alert = LowSpaceAlert(threshold: 10_000)
        let answers = [20_000, 9_000, 8_000, 12_000, 5_000].map { alert.shouldWarn(available: Int64($0)) }
        #expect(answers == [false, true, false, false, true])
    }
}

actor SchedulerState {
    var runs = 0
    var lastRun: Date?

    func ran() {
        runs += 1
        lastRun = Date()
    }
}
