import Foundation
import StrandAnalytics
import WhoopStore

/// The weekly round-up: Noop's `WeeklyDigestEngine` for the averages, the week-on-week moves and the
/// effort-versus-recovery balance, plus the week's standout days picked straight from Noop's stored rows.
/// Loop writes its own words; Noop's digest sentences use Noop's vocabulary.
struct LoopWeek: Equatable {
    struct Standout: Equatable {
        let day: String
        let value: Double
    }

    struct Average: Equatable {
        let title: String
        /// This week's average, already in display units.
        let value: Double
        /// Change on last week, same units; nil without enough of last week to compare.
        let change: Double?
        /// True when a higher value is the better outcome (resting heart rate is the exception).
        let higherIsBetter: Bool
        let format: (Double) -> String

        static func == (a: Average, b: Average) -> Bool {
            a.title == b.title && a.value == b.value && a.change == b.change
        }
    }

    /// Monday and Sunday of the week shown.
    var weekStart = ""
    var weekEnd = ""
    /// True when this is last week (shown on a Monday, before this week has anything in it).
    var isLastWeek = false
    var daysWithData = 0
    var balance: BalanceRead = .insufficient
    var bestNight: Standout?
    var hardestDay: Standout?
    var bestRecovery: Standout?
    var averages: [Average] = []

    static let empty = LoopWeek()
}

@MainActor
enum LoopWeekReader {
    static func read(repo: Repository, today: LoopToday) async -> LoopWeek {
        let todayKey = repo.today?.day ?? Repository.localDayKey(Repository.logicalDay(Date()))
        let rest = await repo.exploreSeries(key: "sleep_performance", source: "my-whoop")

        // Noop's stored rows, with today's live values laid over today (the same figures Home shows).
        var charge: [String: Double] = [:], effort: [String: Double] = [:], sleepScore: [String: Double] = [:]
        var rhr: [String: Double] = [:], hrv: [String: Double] = [:], sleepMin: [String: Double] = [:]
        for d in repo.days {
            if let v = d.recovery { charge[d.day] = v }
            if let v = d.strain { effort[d.day] = v }
            if let v = d.restingHr { rhr[d.day] = Double(v) }
            if let v = d.avgHrv { hrv[d.day] = v }
            if let v = d.totalSleepMin, v > 0 { sleepMin[d.day] = v }
        }
        for p in rest { sleepScore[p.day] = p.value }
        if let s = today.recovery.score { charge[todayKey] = Double(s) }
        if let e = today.effort { effort[todayKey] = e }
        if let m = today.sleepMin { sleepMin[todayKey] = m }

        let series: [WeeklyMetric: [String: Double]] = [.charge: charge, .effort: effort, .rest: sleepScore,
                                                          .rhr: rhr, .hrv: hrv]
        var digest = WeeklyDigestEngine.build(byMetric: series, anchorDay: todayKey)
        var out = LoopWeek()
        // Monday (or any week with under two days in it yet): round up the week just gone instead.
        let thisWeekDays = Set(charge.keys).union(sleepMin.keys).filter { $0 >= digest.weekStart && $0 <= digest.weekEnd }
        if thisWeekDays.count < 2 {
            digest = WeeklyDigestEngine.build(byMetric: series,
                                              anchorDay: WeeklyDigestEngine.addDays(digest.weekStart, -1))
            out.isLastWeek = true
        }
        out.weekStart = digest.weekStart
        out.weekEnd = digest.weekEnd
        out.daysWithData = digest.daysWithData
        out.balance = digest.balance

        func inWeek(_ m: [String: Double]) -> [(String, Double)] {
            m.filter { $0.key >= digest.weekStart && $0.key <= digest.weekEnd }.map { ($0.key, $0.value) }
        }
        out.bestNight = inWeek(sleepMin).max { $0.1 < $1.1 }.map { .init(day: $0.0, value: $0.1) }
        out.hardestDay = inWeek(effort).max { $0.1 < $1.1 }.map { .init(day: $0.0, value: $0.1) }
        out.bestRecovery = inWeek(charge).max { $0.1 < $1.1 }.map { .init(day: $0.0, value: $0.1) }

        // Averages against last week. Sleep is in hours asleep (Loop's measure), the rest from the digest.
        let lastStart = WeeklyDigestEngine.addDays(digest.weekStart, -7)
        let lastEnd = WeeklyDigestEngine.addDays(digest.weekStart, -1)
        let sleepThis = inWeek(sleepMin).map(\.1)
        let sleepLast = sleepMin.filter { $0.key >= lastStart && $0.key <= lastEnd }.map(\.value)
        func mean(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }

        func digestAverage(_ m: WeeklyMetric, _ title: String, _ format: @escaping (Double) -> String) -> LoopWeek.Average? {
            guard let s = digest.summary(m), s.thisWeek.n > 0 else { return nil }
            let enough = s.weekOverWeek.previous.n >= WeeklyDigestEngine.minDaysForFocus
                && s.thisWeek.n >= WeeklyDigestEngine.minDaysForFocus
            return .init(title: title, value: s.thisWeek.mean, change: enough ? s.wowDelta : nil,
                         higherIsBetter: m.higherIsBetter, format: format)
        }
        if let a = digestAverage(.charge, "Recovery", { "\(Int($0.rounded()))" }) { out.averages.append(a) }
        if let m = mean(sleepThis) {
            let last = mean(sleepLast)
            out.averages.append(.init(title: "Sleep", value: m,
                                      change: sleepLast.count >= 3 && sleepThis.count >= 3 ? last.map { m - $0 } : nil,
                                      higherIsBetter: true, format: { LoopFormat.duration($0 * 60) }))
        }
        if let a = digestAverage(.effort, "Effort", { "\(Int($0.rounded()))" }) { out.averages.append(a) }
        if let a = digestAverage(.rhr, "Resting heart rate", { "\(Int($0.rounded())) bpm" }) { out.averages.append(a) }
        if let a = digestAverage(.hrv, "Heart variability", { "\(Int($0.rounded())) ms" }) { out.averages.append(a) }
        return out
    }
}
