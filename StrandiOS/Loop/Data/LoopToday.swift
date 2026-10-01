import Foundation
import StrandAnalytics
import WhoopStore

/// Everything Loop's Home needs about today, read through Noop's own models and helpers so Loop's
/// numbers always match what Noop computes. Nothing here scores, stores or talks to the strap: it
/// resolves the same values Liquid Today resolves in its `load()`, with the same precedence rules.
struct LoopToday: Equatable {
    enum Recovery: Equatable {
        /// Today's score, 0-100.
        case scored(Int)
        /// No score for today; showing last night's real score instead.
        case carried(Int)
        /// First nights: Noop is still learning his normal. `nights` already counted.
        case learning(nights: Int, of: Int)
        /// Nothing honest to show.
        case noData

        var score: Int? {
            switch self {
            case .scored(let s), .carried(let s): return s
            case .learning, .noData: return nil
            }
        }
    }

    var recovery: Recovery = .noData
    /// Minutes asleep last night, nil when there's no night yet.
    var sleepMin: Double?
    /// The night's need in minutes, from `LoopSleepNeed` (the one need every Loop readout uses).
    var sleepNeedMin: Double = 540
    /// Noop's own sleep score for last night (sleep_performance, 0-100), nil when not scored.
    var sleepScore: Int?
    /// Today's effort on Loop's 0-100 scale (Noop's native axis), nil when too few readings.
    var effort: Double?
    var steps: Int?

    static let empty = LoopToday()
}

@MainActor
enum LoopTodayReader {
    static func read(repo: Repository, profile: ProfileStore) async -> LoopToday {
        var out = LoopToday()
        let todayKey = repo.today?.day ?? Repository.localDayKey(Repository.logicalDay(Date()))
        let day = repo.today ?? repo.days.last(where: { $0.day == todayKey })

        // Recovery: the identical resolution Liquid Today uses (#543 carry + calibration).
        let calNights = RecoveryScorer.calibrationNights(nightlyHrv: repo.days.map(\.avgHrv),
                                                         dayKeys: repo.days.map(\.day),
                                                         hasRecovery: day?.recovery != nil)
        let prior = TodayView.lastScoredRecoveryDay(days: repo.days, selectedDayKey: todayKey,
                                                     isToday: true, todayScored: day?.recovery != nil,
                                                     isCalibrating: calNights != nil)
        switch LiquidTodayView.ChargeDisplay.resolve(todayRecovery: day?.recovery, priorScored: prior,
                                                     calibrationNights: calNights, todayKey: todayKey) {
        case .scored(let p): out.recovery = .scored(Int(p.rounded()))
        case .carried(let p, _): out.recovery = .carried(Int(p.rounded()))
        case .calibrating(let n): out.recovery = .learning(nights: n, of: Baselines.minNightsSeed)
        case .noData: out.recovery = .noData
        }

        // Sleep: last night's total against Loop's one need (see LoopSleepNeed).
        if let asleep = day?.totalSleepMin, asleep > 0 { out.sleepMin = asleep }
        out.sleepNeedMin = LoopSleepNeed.minutes(days: repo.days,
                                                 importedNeedMin: day.flatMap { repo.importedSleep[$0.day]?.needMin },
                                                 age: profile.age)
        LoopSleepNeed.syncReminder(needMin: out.sleepNeedMin)

        let rest = await repo.exploreSeries(key: "sleep_performance", source: "my-whoop")
        out.sleepScore = rest.last(where: { $0.day == todayKey }).map { Int($0.value.rounded()) }

        // Effort: today's live in-progress score over the same window and parameters Liquid Today
        // uses, floored by the stored row through Noop's shared `effectiveEffort`.
        let window = await effortWindow(repo: repo, todayKey: todayKey)
        let hr = await repo.hrSamples(from: window.from, to: window.to, limit: 200_000)
        let live = StrainScorer.strain(hr, maxHR: profile.effortHRmax,
                                       restingHR: day?.restingHr.map(Double.init) ?? StrainScorer.defaultRestingHR,
                                       method: PuffinExperiment.effortMethod, sex: profile.sex)
        out.effort = StrainScorer.effectiveEffort(live: live, stored: day?.strain)

        // Steps: measured strap count first, then Noop's motion estimate (Liquid Today's precedence,
        // minus the imported Apple Health count, which Loop doesn't use).
        if let s = day?.steps {
            out.steps = s
        } else {
            let est = await repo.exploreSeries(key: "steps_est", source: "my-whoop")
            out.steps = est.last(where: { $0.day == todayKey }).map { Int($0.value.rounded()) }
        }
        return out
    }

    /// Today's effort window: day-cycle onset when Noop's "main sleep" day cycle is on, else midnight, to now.
    private static func effortWindow(repo: Repository, todayKey: String) async -> (from: Int, to: Int) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: Repository.logicalDay(Date()))
        let calendarFrom = Int(dayStart.timeIntervalSince1970)
        let now = Int(Date().timeIntervalSince1970)
        let mode = DayCycleMode.persisted(UserDefaults.standard.string(forKey: DayCycleMode.storageKey)
                                          ?? DayCycleMode.sleepOnset.rawValue)
        guard mode == .sleepOnset else { return (calendarFrom, now) }
        let markers = await repo.exploreSeries(key: DayCycleIntelligenceIntegration.onsetKey, source: "my-whoop")
        let from = markers.last(where: { $0.day == todayKey }).map { Int($0.value) } ?? calendarFrom
        return (from, max(from, now - 1))
    }
}

/// One earlier day for Home's swipe-back, read from Noop's stored nightly row only. Nothing is
/// re-scored: the recovery, sleep, effort and steps are the values Noop banked for that day.
@MainActor
enum LoopPastDayReader {
    /// How far back Home lets you swipe, today included.
    static let span = 14

    /// Day keys from the oldest to today, the order Home's pages run in.
    static func keys(repo: Repository, now: Date = .now) -> [(key: String, date: Date)] {
        let cal = Calendar.current
        let logicalToday = Repository.logicalDay(now)
        let todayKey = repo.today?.day ?? Repository.localDayKey(logicalToday)
        return (0..<span).reversed().compactMap { back in
            guard let d = cal.date(byAdding: .day, value: -back, to: logicalToday) else { return nil }
            return (back == 0 ? todayKey : Repository.localDayKey(d), d)
        }
    }

    static func read(repo: Repository, dayKeys: [String], age: Int?) async -> [String: LoopToday] {
        let rest = await repo.exploreSeries(key: "sleep_performance", source: "my-whoop")
        let stepsEst = await repo.exploreSeries(key: "steps_est", source: "my-whoop")
        let need = LoopSleepNeed.minutes(days: repo.days, importedNeedMin: nil, age: age)

        var out: [String: LoopToday] = [:]
        for key in dayKeys {
            var t = LoopToday()
            let row = repo.days.last(where: { $0.day == key })
            t.recovery = row?.recovery.map { .scored(Int($0.rounded())) } ?? .noData
            if let asleep = row?.totalSleepMin, asleep > 0 { t.sleepMin = asleep }
            t.sleepNeedMin = (repo.importedSleep[key]?.needMin).flatMap { $0 > 0 ? $0 : nil } ?? need
            t.sleepScore = rest.last(where: { $0.day == key }).map { Int($0.value.rounded()) }
            t.effort = row?.strain
            t.steps = row?.steps ?? stepsEst.last(where: { $0.day == key }).map { Int($0.value.rounded()) }
            out[key] = t
        }
        return out
    }
}
