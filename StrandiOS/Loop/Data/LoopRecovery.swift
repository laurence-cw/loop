import Foundation
import StrandAnalytics
import WhoopStore

/// One body measure against "your normal". Read-only: the value is Noop's stored nightly figure
/// (with Noop's own prior-night carry) and the normal range is Noop's own personal baseline fold.
struct LoopVital: Equatable {
    enum Reading: Equatable {
        /// Below / inside / above the normal band (|z| ≤ 1 is normal, Noop's own rule).
        case low, normal, high
    }

    /// Tonight's (or the carried night's) value, nil when there's none.
    var value: Double?
    /// Your normal: baseline ± one sigma. Nil while Noop is still learning it.
    var normalLow: Double?
    var normalHigh: Double?
    var z: Double?

    var reading: Reading? {
        guard let z else { return nil }
        if z > 1 { return .high }
        if z < -1 { return .low }
        return .normal
    }

    var hasNormal: Bool { normalLow != nil && normalHigh != nil }
}

struct LoopRecovery: Equatable {
    var heartVariability = LoopVital()
    var restingHeartRate = LoopVital()
    var breathing = LoopVital()
    /// Skin temperature change from your normal, °C (Noop's stored deviation).
    var temperatureChange: Double?

    static let empty = LoopRecovery()

    /// Temperature counts as "a bit off" beyond half a degree from your normal.
    static let temperatureOffBy: Double = 0.5
}

@MainActor
enum LoopRecoveryReader {
    static func read(repo: Repository) -> LoopRecovery {
        var out = LoopRecovery()
        let days = repo.days
        let todayKey = repo.today?.day ?? Repository.localDayKey(Repository.logicalDay(Date()))
        let today = repo.today ?? days.last(where: { $0.day == todayKey })
        // Baselines are folded from the nights BEFORE today, so tonight's value is judged against
        // a normal it didn't help set.
        let prior = days.filter { $0.day < todayKey }

        let hrv = today?.avgHrv ?? Repository.lastHrvDay(days: days, todayKey: todayKey)?.avgHrv
        let hrvBase = Baselines.foldHistory(prior.map(\.avgHrv), dayKeys: prior.map(\.day), cfg: Baselines.hrvCfg)
        out.heartVariability = vital(hrv, hrvBase)

        let rhr = (today?.restingHr ?? Repository.lastRestingHrDay(days: days, todayKey: todayKey)?.restingHr)
            .map(Double.init)
        let rhrBase = Baselines.foldHistory(prior.map { $0.restingHr.map(Double.init) }, cfg: Baselines.restingHRCfg)
        out.restingHeartRate = vital(rhr, rhrBase)

        let resp = today?.respRateBpm ?? Repository.lastRespDay(days: days, todayKey: todayKey)?.respRateBpm
        let respBase = Baselines.foldHistory(prior.map(\.respRateBpm), cfg: Baselines.respCfg)
        out.breathing = vital(resp, respBase)

        // Imports can store an absolute wrist °C in the same column; only a true change is shown.
        let temp = today?.skinTempDevC
            ?? Repository.lastSkinTempReadingDay(days: days, todayKey: todayKey)?.skinTempDevC
        out.temperatureChange = temp.flatMap { VitalBands.isAbsoluteSkinTemp($0) ? nil : $0 }
        return out
    }

    private static func vital(_ value: Double?, _ base: BaselineState) -> LoopVital {
        var v = LoopVital(value: value)
        guard base.usable else { return v }
        let sigma = Baselines.sigma(base)
        v.normalLow = base.baseline - sigma
        v.normalHigh = base.baseline + sigma
        if let value { v.z = Baselines.deviation(value, state: base).z }
        return v
    }
}
