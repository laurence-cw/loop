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
        // Never from inside the recent pass, never for a window no wider than it, never for a history repair.
        XCTAssertFalse(runs(21, recentOnly: true, interrupted: true, background: true))
        XCTAssertFalse(runs(IntelligenceEngine.recentFirstDays, interrupted: true))
        XCTAssertFalse(runs(2, background: true))
        XCTAssertFalse(runs(365, repair: true, interrupted: true))
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

    private func lastNight() -> [HRSample] {
        let start = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970) - 86_400
        return (0..<(24 * 3_600)).map { i in
            let asleep = i >= 16 * 3_600
            let bpm = asleep ? 64 + Int(sin(Double(i) / 900) * 5) : 74 + Int(sin(Double(i) / 500) * 11)
            return HRSample(ts: start - 16 * 3_600 + i, bpm: bpm)
        }
    }
}
