import Foundation
import WhoopStore

/// Last night and this week's sleep, read through Noop's stored nightly rows and its own
/// main-night resolver (`SleepView.mainNightSpan`), so Loop and Noop agree on which block is "the night".
struct LoopSleep: Equatable {
    struct Night: Equatable {
        /// Day key the night belongs to (the morning you woke up).
        let day: String
        /// Bedtime and wake time, unix seconds. Nil for a night with no sleep recorded.
        let bed: Int?
        let wake: Int?
    }

    var asleepMin: Double?
    var needMin: Double = 450
    /// Noop's own sleep score, 0-100.
    var score: Int?
    var lightMin: Double?
    var deepMin: Double?
    var dreamMin: Double?
    var awakeMin: Double?
    /// Asleep ÷ time in bed, 0-100.
    var qualityPct: Int?
    var bed: Int?
    var wake: Int?
    /// Monday to Sunday of the current week. Days still to come are omitted.
    var week: [Night] = []
    /// Stages are not reliable on a WHOOP 5.0 / MG yet.
    var unreliableStages = false

    static let empty = LoopSleep()

    var hasStages: Bool { (lightMin ?? 0) + (deepMin ?? 0) + (dreamMin ?? 0) > 0 }
}

@MainActor
enum LoopSleepReader {
    static func read(repo: Repository, today: LoopToday, isWhoop5: Bool) async -> LoopSleep {
        var out = LoopSleep()
        out.unreliableStages = isWhoop5
        out.asleepMin = today.sleepMin
        out.needMin = today.sleepNeedMin
        out.score = today.sleepScore

        let todayKey = repo.today?.day ?? Repository.localDayKey(Repository.logicalDay(Date()))
        let day = repo.today ?? repo.days.last(where: { $0.day == todayKey })
        out.lightMin = day?.lightMin
        out.deepMin = day?.deepMin
        out.dreamMin = day?.remMin
        if let asleep = day?.totalSleepMin, asleep > 0, var e = day?.efficiency, e > 0 {
            if e > 1.5 { e /= 100 }   // some import paths store percent (SleepView's rule)
            if e > 0.3, e <= 1 {
                out.qualityPct = Int((e * 100).rounded())
                out.awakeMin = asleep * (1 - e) / e
            }
        }

        let midsleep = await repo.habitualMidsleepSec()
        let cal = Calendar.current
        let logicalToday = Repository.logicalDay(Date())
        if let span = span(endingOn: logicalToday, sleeps: repo.sleeps, midsleep: midsleep, cal: cal) {
            out.bed = span.start
            out.wake = span.end
        }

        // This week, Monday first.
        var mondayCal = Calendar(identifier: .iso8601)
        mondayCal.timeZone = cal.timeZone
        let weekStart = mondayCal.dateInterval(of: .weekOfYear, for: logicalToday)?.start ?? logicalToday
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: offset, to: weekStart), d <= logicalToday else { break }
            let s = span(endingOn: d, sleeps: repo.sleeps, midsleep: midsleep, cal: cal)
            out.week.append(.init(day: Repository.localDayKey(d), bed: s?.start, wake: s?.end))
        }
        return out
    }

    /// The main night whose wake time falls on `day`.
    private static func span(endingOn day: Date, sleeps: [CachedSleepSession], midsleep: Int?,
                             cal: Calendar) -> (start: Int, end: Int)? {
        let start = Int(cal.startOfDay(for: day).timeIntervalSince1970)
        let end = start + 24 * 60 * 60
        let candidates = sleeps.filter { $0.endTs > start && $0.endTs <= end }
        return SleepView.mainNightSpan(candidates, habitualMidsleepSec: midsleep)
    }
}
