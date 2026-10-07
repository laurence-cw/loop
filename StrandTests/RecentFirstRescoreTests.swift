import XCTest
import Foundation
import WhoopProtocol
import WhoopStore
import StrandAnalytics
@testable import Strand

/// #1538 follow-up: the short recent-first pass that runs before a full window when the last full pass
/// was cut short or this one starts in the background.
@MainActor
final class RecentFirstRescoreTests: XCTestCase {
    private let canonical = "my-whoop"
    private let active = "new-five"

    func testRunsOnlyForAFullWindowThatNeedsIt() {
        func runs(_ maxDays: Int, recentOnly: Bool = false, repair: Bool = false,
                  interrupted: Bool = false, background: Bool = false) -> Bool {
            IntelligenceEngine.runsRecentFirst(maxDays: maxDays, recentOnly: recentOnly,
                                               preserveUnscoredHistory: repair,
                                               owedFromInterruptedPass: interrupted, backgrounded: background)
        }
        // A foreground pass on a healthy install is unchanged.
        XCTAssertFalse(runs(21))
        // Needed: the last full pass was cut short, or this one starts in the background.
        XCTAssertTrue(runs(21, interrupted: true))
        XCTAssertTrue(runs(21, background: true))
        // Never from inside the recent pass, never for a window no wider than it.
        XCTAssertFalse(runs(21, recentOnly: true, interrupted: true, background: true))
        XCTAssertFalse(runs(IntelligenceEngine.recentFirstDays, interrupted: true))
        XCTAssertFalse(runs(2, background: true))
        // A one-time history repair holds the lock for hours: the newest nights go first, always.
        XCTAssertTrue(runs(4_000, repair: true))
    }

    /// The recent pass persists scores but is not the full window: it must leave the watermark, the owed
    /// mark and the banked pass cost for the full pass that owes them.
    func testRecentPassScoresButLeavesTheFullPassDebtAlone() async throws {
        let defaults = UserDefaults.standard
        let keys = ["noop.analyzeWatermark", RescoreBackgroundScheduler.owedKey,
                    RescoreBackgroundScheduler.owedTokenKey, RescoreBackgroundScheduler.lastPassSecondsKey,
                    DayCycleMode.storageKey]
        let saved = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.set(DayCycleMode.midnight.rawValue, forKey: DayCycleMode.storageKey)

        let store = try await WhoopStore.inMemory()
        let registry = DeviceRegistryStore(dbQueue: store.registryWriter)
        try registry.add(PairedDevice(id: canonical, brand: "WHOOP", model: "WHOOP",
            sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .paired, addedAt: 1, lastSeenAt: 1))
        try registry.add(PairedDevice(id: active, brand: "WHOOP", model: "5.0",
            sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .active, addedAt: 2, lastSeenAt: 2))
        _ = try await store.insert(Streams(hr: lastNight()), deviceId: active)
        let repo = Repository(deviceId: active)
        repo.setStoreForTesting(store)
        let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: canonical)
        var lines: [String] = []
        engine.diagnosticSink = { line, _ in lines.append(line) }

        // A full pass was cut short earlier: the debt is outstanding.
        _ = RescoreBackgroundScheduler.markRescoreOwed(passStarting: true)
        let lastPassBefore = defaults.object(forKey: RescoreBackgroundScheduler.lastPassSecondsKey) as? Double

        await engine.analyzeRecent(maxDays: IntelligenceEngine.recentFirstDays, force: true, recentOnly: true)
        let scored = try await store.dailyMetrics(deviceId: canonical + "-noop", from: "0000-00-00", to: "9999-99-99")
        XCTAssertFalse(scored.isEmpty, "the recent pass persists what it scored")
        XCTAssertNil(defaults.string(forKey: "noop.analyzeWatermark"), "the watermark belongs to the full window")
        XCTAssertTrue(RescoreBackgroundScheduler.isRescoreOwed, "the full pass still owes the window")
        XCTAssertEqual(defaults.object(forKey: RescoreBackgroundScheduler.lastPassSecondsKey) as? Double,
                       lastPassBefore, "a fraction of the window must not be banked as a full pass's cost")

        // The full pass, with the debt from an interrupted pass, runs the recent pass first and then settles.
        lines.removeAll()
        await engine.analyzeRecent(maxDays: 5, force: true)
        XCTAssertTrue(lines.contains { $0.hasPrefix("re-score: recent-first") }, lines.joined(separator: "\n"))
        // The recent pass starts and finishes inside the full one, before the full window is scored.
        let recentStart = lines.firstIndex { $0.hasPrefix("re-score: trigger=recent-first") }
        let done = lines.indices.filter { lines[$0].hasPrefix("re-score: done") }
        XCTAssertEqual(done.count, 2, "the recent pass and the full pass each complete")
        if let recentStart, done.count == 2 {
            XCTAssertLessThan(recentStart, done[0])
        } else {
            XCTFail("the recent pass never started: \(lines.joined(separator: "\n"))")
        }
        XCTAssertNotNil(defaults.string(forKey: "noop.analyzeWatermark"))
        XCTAssertFalse(RescoreBackgroundScheduler.isRescoreOwed)
    }

    /// A trigger landing mid-way through a one-time history repair wants an ordinary window afterwards. It
    /// used to re-run the whole repair, and withhold the repair's completion while it did, so on a phone
    /// whose strap offloads during every long pass the repair repeated back to back and never finished.
    func testATriggerDuringAHistoryRepairReArmsAnOrdinaryWindow() async throws {
        let defaults = UserDefaults.standard
        let keys = ["noop.analyzeWatermark", RescoreBackgroundScheduler.owedKey,
                    RescoreBackgroundScheduler.owedTokenKey, RescoreBackgroundScheduler.lastPassSecondsKey,
                    DayCycleMode.storageKey]
        let saved = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.set(DayCycleMode.midnight.rawValue, forKey: DayCycleMode.storageKey)

        let store = try await WhoopStore.inMemory()
        let registry = DeviceRegistryStore(dbQueue: store.registryWriter)
        try registry.add(PairedDevice(id: active, brand: "WHOOP", model: "5.0",
            sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .active, addedAt: 2, lastSeenAt: 2))
        _ = try await store.insert(Streams(hr: lastNight()), deviceId: active)
        let repo = Repository(deviceId: active)
        repo.setStoreForTesting(store)
        let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: canonical)
        var lines: [String] = []
        var injected = false
        engine.diagnosticSink = { line, _ in
            lines.append(line)
            // An offload's forced re-score lands while the repair holds the lock.
            if !injected, line.hasPrefix("re-score: trigger=repair-test") {
                injected = true
                Task { @MainActor in await engine.analyzeRecent(force: true) }
            }
        }
        var completions = 0
        await engine.analyzeRecent(maxDays: 30, triggerLabel: "repair-test", preserveUnscoredHistory: true) {
            completions += 1
        }
        // The follow-up pass runs on its own task; give it time to finish.
        for _ in 0..<200 where lines.filter({ $0.hasPrefix("re-score: done") }).count < 3 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(injected)
        XCTAssertEqual(completions, 1, "the repair finished and must say so, once")
        XCTAssertEqual(lines.filter { $0.hasPrefix("re-score: trigger=repair-test") }.count, 1,
                       "the repair must not run again for an ordinary trigger: \(lines.joined(separator: "\n"))")
        XCTAssertEqual(lines.filter { $0.hasPrefix("re-score: done") }.count, 3,
                       "recent pass, repair, then one ordinary follow-up")
    }

    /// Recovery is scored against a baseline of earlier nights. A recent pass covers three, too few to seed
    /// it, and wrote recovery as nil over three good days on a field phone. It must seed from the computed
    /// nights already stored before its window, the ones the full window would have scored.
    func testARecentPassKeepsRecoveryBySeedingFromStoredNights() async throws {
        let defaults = UserDefaults.standard
        let keys = ["noop.analyzeWatermark", RescoreBackgroundScheduler.owedKey,
                    RescoreBackgroundScheduler.owedTokenKey, RescoreBackgroundScheduler.lastPassSecondsKey,
                    DayCycleMode.storageKey, "noop.hrvBaselineEpoch", "noop.recoveryBaselineEpoch",
                    "analyzeRecent.stepsMotionCache.v1",
                    PuffinExperiment.experimentalSleepV2Key, PuffinExperiment.motionAwareWakeKey]
        let saved = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.set(DayCycleMode.midnight.rawValue, forKey: DayCycleMode.storageKey)
        defaults.set(true, forKey: PuffinExperiment.experimentalSleepV2Key)
        defaults.set(false, forKey: PuffinExperiment.motionAwareWakeKey)

        let store = try await WhoopStore.inMemory()
        let registry = DeviceRegistryStore(dbQueue: store.registryWriter)
        try registry.add(PairedDevice(id: canonical, brand: "WHOOP", model: "4.0",
            sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .paired, addedAt: 1, lastSeenAt: 1))
        try registry.add(PairedDevice(id: active, brand: "WHOOP", model: "5.0",
            sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .active, addedAt: 2, lastSeenAt: 2))
        let night = nightWithBeats()
        _ = try await store.insert(Streams(hr: night.hr, rr: night.rr), deviceId: canonical)
        // Fourteen computed nights from earlier passes, before the recent window.
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        let earlier = (4...17).map { back in
            DailyMetric(day: f.string(from: today.addingTimeInterval(-Double(back) * 86_400)),
                totalSleepMin: 480, efficiency: 0.9, deepMin: 90, remMin: 90, lightMin: 300,
                disturbances: 0, restingHr: 60, avgHrv: 32 + Double(back % 3), recovery: 60,
                strain: nil, exerciseCount: nil)
        }
        _ = try await store.upsertDailyMetrics(earlier, deviceId: canonical + "-noop")
        let repo = Repository(deviceId: active)
        repo.setStoreForTesting(store)
        let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: canonical)

        await engine.analyzeRecent(maxDays: IntelligenceEngine.recentFirstDays, force: true, recentOnly: true)
        let rows = try await store.dailyMetrics(deviceId: canonical + "-noop", from: night.day, to: night.day)
        let row = try XCTUnwrap(rows.first)
        XCTAssertNotNil(row.avgHrv, "fixture: the night must have an HRV to score recovery from")
        XCTAssertNotNil(row.recovery, "a recent pass must score recovery against the stored earlier nights")
    }

    /// The same night `IntelligenceRRSourceTests` scores: awake from 08:00 the day before yesterday, asleep
    /// from midnight to 08:00 yesterday, with beat-to-beat intervals throughout.
    private func nightWithBeats() -> (day: String, hr: [HRSample], rr: [RRInterval]) {
        let start = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970) - 86_400
        let day = Repository.localDayKey(Date(timeIntervalSince1970: Double(start)))
        var hr: [HRSample] = []
        var rr: [RRInterval] = []
        for i in 0..<(24 * 3_600) {
            let asleep = i >= 16 * 3_600
            let phase = asleep ? i - 16 * 3_600 : i
            let bpm = asleep ? 64 + Int(sin(Double(phase) / 900) * 5)
                             : 74 + Int(sin(Double(phase) / 500) * 11)
            let ts = start - 16 * 3_600 + i
            hr.append(HRSample(ts: ts, bpm: bpm))
            rr.append(RRInterval(ts: ts, rrMs: 900 + (i.isMultiple(of: 2) ? 16 : -16)))
        }
        return (day, hr, rr)
    }

    /// Two triggers at once (an offload and a re-point, both at launch) ran two passes side by side on a
    /// field phone. The second must queue behind the first and run after it, never beside it.
    func testTwoTriggersAtOnceRunOnePassThenTheOther() async throws {
        let defaults = UserDefaults.standard
        let keys = ["noop.analyzeWatermark", RescoreBackgroundScheduler.owedKey,
                    RescoreBackgroundScheduler.owedTokenKey, RescoreBackgroundScheduler.lastPassSecondsKey,
                    DayCycleMode.storageKey]
        let saved = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.set(DayCycleMode.midnight.rawValue, forKey: DayCycleMode.storageKey)

        let store = try await WhoopStore.inMemory()
        let registry = DeviceRegistryStore(dbQueue: store.registryWriter)
        try registry.add(PairedDevice(id: active, brand: "WHOOP", model: "5.0",
            sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .active, addedAt: 2, lastSeenAt: 2))
        _ = try await store.insert(Streams(hr: lastNight()), deviceId: active)
        let repo = Repository(deviceId: active)
        repo.setStoreForTesting(store)
        let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: canonical)
        var lines: [String] = []
        engine.diagnosticSink = { line, _ in lines.append(line) }

        async let first: Void = engine.analyzeRecent(maxDays: 5, force: true)
        async let second: Void = engine.analyzeRecent(maxDays: 5, force: true)
        _ = await (first, second)
        for _ in 0..<200 where lines.filter({ $0.hasPrefix("re-score: done") }).count < 2 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let starts = lines.indices.filter { lines[$0].hasPrefix("re-score: trigger=") }
        let done = lines.indices.filter { lines[$0].hasPrefix("re-score: done") }
        XCTAssertEqual(done.count, 2, lines.joined(separator: "\n"))
        XCTAssertEqual(starts.count, 2, lines.joined(separator: "\n"))
        if starts.count == 2, let firstDone = done.first {
            XCTAssertGreaterThan(starts[1], firstDone, "the second pass started before the first finished")
        }
    }

    func testBackgroundStandsDownOnlyAfterTwoUnfinishedAttempts() {
        typealias P = RescoreBackgroundPolicy
        XCTAssertFalse(P.standsDownInBackground(isBackground: true, inProcessingTask: false, unfinishedBackgroundAttempts: 1))
        XCTAssertTrue(P.standsDownInBackground(isBackground: true, inProcessingTask: false, unfinishedBackgroundAttempts: 2))
        // Never in the foreground, and never inside a processing task, where iOS lifts the CPU limit.
        XCTAssertFalse(P.standsDownInBackground(isBackground: false, inProcessingTask: false, unfinishedBackgroundAttempts: 9))
        XCTAssertFalse(P.standsDownInBackground(isBackground: true, inProcessingTask: true, unfinishedBackgroundAttempts: 9))
        // It lapses: three hours after the last attempt, ordinary background time gets another try.
        XCTAssertTrue(P.standsDownInBackground(isBackground: true, inProcessingTask: false,
                                               unfinishedBackgroundAttempts: 5, secondsSinceLastAttempt: 600))
        XCTAssertFalse(P.standsDownInBackground(isBackground: true, inProcessingTask: false,
                                                unfinishedBackgroundAttempts: 5,
                                                secondsSinceLastAttempt: P.standDownLapseSeconds + 1))
    }

    private func lastNight() -> [HRSample] {
        let start = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970) - 86_400
        return (0..<(24 * 3_600)).map { i in
            let asleep = i >= 16 * 3_600
            let bpm = asleep ? 64 + Int(sin(Double(i) / 900) * 5) : 74 + Int(sin(Double(i) / 500) * 11)
            return HRSample(ts: start - 16 * 3_600 + i, bpm: bpm)
        }
    }
}
