import Foundation
import StrandAnalytics
import WhoopStore

/// One sleep need for every Loop readout: the Home and Sleep rings, sleep debt, tonight's bedtime and
/// the bedtime reminder. Two figures that both claim to be "what you need" must never disagree.
///
/// The rule is Noop's own `AnalyticsEngine.Rest.personalizedNeedHours` (the need its sleep-debt ledger
/// is measured against), given the wearer's age. Under 18 that floors the need at 9 h, the population
/// target for teenagers; Noop's own Sleep screen passes no age and so measures everyone against the
/// adult 8 h. An imported WHOOP need for the day still wins, as it always has.
enum LoopSleepNeed {
    static func minutes(days: [DailyMetric], importedNeedMin: Double?, age: Int?) -> Double {
        if let importedNeedMin, importedNeedMin > 0 { return importedNeedMin }
        let nightly = days.compactMap { $0.totalSleepMin }.filter { $0 > 0 }.map { $0 / 60 }
        return AnalyticsEngine.Rest.personalizedNeedHours(nightlyHours: nightly, age: age) * 60
    }

    /// Keep Noop's bedtime reminder on the same need, so the reminder lands its lead before the bedtime
    /// the Sleep screen shows. Rounded to 5 minutes, and written only when it actually moved.
    @MainActor
    static func syncReminder(needMin: Double) {
        let rounded = Int((needMin / 5).rounded()) * 5
        if abs(rounded - WindDownNudge.sleepNeedMinutes) >= 5 { WindDownNudge.setSleepNeedMinutes(rounded) }
    }

    /// Noop's recency-weighted sleep debt over the last fortnight, against the same need. Naps are not
    /// credited (Loop doesn't record them), which only ever makes the estimate a little cautious.
    static func debt(days: [DailyMetric], needMin: Double) -> SleepDebtLedger {
        SleepDebt.ledger(series: days.map { ($0.day, SleepDebt.creditedSleepMin(mainSleepMin: $0.totalSleepMin)) },
                         needHours: needMin / 60)
    }
}

extension LoopSleepNeed {
    /// What stands in for last night's sleep on today's page while it isn't in yet. "No data" read as if
    /// tonight's sleep were missing. In the evening the useful fact is tonight's bedtime, so that shows
    /// ("Bed 9:45pm", or "Bed now" once it has passed); earlier in the day, an honest "Not in yet", since
    /// last night appears once the strap has synced and the night is worked out. Earlier days keep
    /// "No data": their night is not coming.
    @MainActor
    static func missingWord(isToday: Bool, needMin: Double, now: Date = .now, cal: Calendar = .current) -> String {
        guard isToday else { return "No data" }
        let hour = cal.component(.hour, from: now)
        if hour >= 18 || hour < 2,
           let plan = LoopTonightPlan.make(now: now, needMin: needMin, cal: cal,
                                           wakeMinutes: WindDownNudge.wakeMinutes(forWeekday:)) {
            return plan.late ? "Bed now" : "Bed \(LoopFormat.clock(plan.asleepBy))"
        }
        return "Not in yet"
    }
}

/// Tonight's bedtime: the next wake-up set in Loop's Settings (school days and weekends), minus the
/// sleep need. Worked out from the clock each time it is shown, so it is never stale.
struct LoopTonightPlan: Equatable {
    /// The wake-up it plans for.
    let wake: Date
    /// When to be asleep by to get the full need before `wake`.
    let asleepBy: Date
    /// True when `asleepBy` has already passed: then `available` is what's still possible.
    let late: Bool
    /// Minutes of sleep still possible before `wake`, counted from now.
    let availableMin: Double

    /// `wakeMinutes(weekday)` is Noop's per-weekday wake time (WindDownNudge.wakeMinutes(forWeekday:)).
    static func make(now: Date, needMin: Double, cal: Calendar = .current,
                     wakeMinutes: (Int) -> Int) -> LoopTonightPlan? {
        let start = cal.startOfDay(for: now)
        for k in 0...2 {
            guard let day = cal.date(byAdding: .day, value: k, to: start) else { continue }
            let wake = day.addingTimeInterval(TimeInterval(wakeMinutes(cal.component(.weekday, from: day)) * 60))
            guard wake > now else { continue }
            let asleepBy = wake.addingTimeInterval(-needMin * 60)
            return LoopTonightPlan(wake: wake, asleepBy: asleepBy, late: asleepBy <= now,
                                   availableMin: wake.timeIntervalSince(now) / 60)
        }
        return nil
    }
}
