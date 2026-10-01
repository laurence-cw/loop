import Foundation
import StrandAnalytics
import WhoopStore

/// The extra reads on Recovery: what moved today's score, stress through the day, and tomorrow's
/// estimate. Every number is Noop's own (`ChargeBreakdownWiring`, `StressDayCurve`,
/// `RecoveryForecaster`); Loop only chooses the words.
struct LoopRecoveryInsights: Equatable {
    /// One term that fed today's score: its Loop name and its real contribution in points.
    struct Driver: Equatable {
        let name: String
        let points: Int
    }

    /// Largest effect first. Empty when the night couldn't honestly be scored.
    var drivers: [Driver] = []
    /// Today's stress per hour, 0 (calm) to 3 (high), nil where there wasn't enough to read.
    var stressHours: [(hour: Int, level: Double?, moving: Bool)] = []
    var stressDayMean: Double?
    var stressPeakHour: Int?
    var forecast: RecoveryForecast?

    static let empty = LoopRecoveryInsights()

    static func == (a: Self, b: Self) -> Bool {
        a.drivers == b.drivers && a.stressDayMean == b.stressDayMean && a.stressPeakHour == b.stressPeakHour
            && a.forecast == b.forecast && a.stressHours.count == b.stressHours.count
    }

    /// Noop's driver labels in the words Loop's own cards already use.
    static func loopName(_ noopLabel: String) -> String {
        switch noopLabel {
        case "Heart rate variability": return "Heart variability"
        case "Sleep quality": return "Sleep"
        case "Respiratory rate": return "Breathing rate"
        case "Skin temperature": return "Temperature"
        default: return noopLabel
        }
    }
}

@MainActor
enum LoopRecoveryInsightsReader {
    static func read(repo: Repository, today: LoopToday) async -> LoopRecoveryInsights {
        var out = LoopRecoveryInsights()
        let todayKey = repo.today?.day ?? Repository.localDayKey(Repository.logicalDay(Date()))

        // What moved it: the same breakdown, baseline epoch and sleep input as Noop's Today screen.
        if let row = repo.today ?? repo.days.last(where: { $0.day == todayKey }), row.recovery != nil {
            if let b = ChargeBreakdownWiring.breakdown(days: repo.days, row: row,
                                                       sleepPerfPercent: today.sleepScore.map(Double.init),
                                                       hrvBaselineEpoch: Baselines.hrvBaselineEpoch()) {
                out.drivers = b.drivers
                    .map { .init(name: LoopRecoveryInsights.loopName($0.label), points: $0.deltaPoints) }
                    .sorted { abs($0.points) > abs($1.points) }
            }
        }

        // Stress through the day: Noop's day curve, the lens its background surfaces use.
        if let curve = await StressDayCurve.today(repo: repo) {
            out.stressHours = curve.result.hours.map { ($0.hour, $0.level, $0.maskedForActivity) }
            out.stressDayMean = curve.result.dayMean
            out.stressPeakHour = curve.result.peak?.hour
        }

        // Tomorrow: Noop's forecaster, assuming tonight's full need (the bedtime the Sleep screen gives).
        let scored = repo.days.filter { $0.day < todayKey }
        out.forecast = RecoveryForecaster.forecast(
            recentCharge: scored.compactMap(\.recovery) + (today.recovery.score.map { [Double($0)] } ?? []),
            recentEffort: scored.compactMap(\.strain),
            todayEffort: today.effort,
            plannedSleepHours: today.sleepNeedMin / 60,
            needHours: today.sleepNeedMin / 60,
            needNights: repo.days.filter { ($0.totalSleepMin ?? 0) > 0 }.count)
        return out
    }
}

#if DEBUG
extension LoopRecoveryInsights {
    /// DEBUG-only `--loop-preview-insights`: a plausible school day, for screenshots.
    static var preview: LoopRecoveryInsights {
        var p = LoopRecoveryInsights()
        p.drivers = [.init(name: "Sleep", points: 9), .init(name: "Heart variability", points: 6),
                     .init(name: "Resting heart rate", points: -4), .init(name: "Breathing rate", points: 1)]
        let levels: [Int: Double] = [7: 1.2, 8: 1.8, 9: 1.1, 10: 0.9, 11: 1.4, 13: 2.4, 14: 2.1, 15: 1.0, 16: 0.7,
                                     17: 0.8, 18: 1.3, 19: 0.6]
        p.stressHours = (6...20).map { h in (h, h == 12 ? nil : levels[h], h == 12) }
        p.stressDayMean = 1.25
        p.stressPeakHour = 13
        p.forecast = RecoveryForecast(charge: 71, band: 9, baseline: 64, plannedSleepHours: 9, needHours: 9,
                                      nights: 14, confidence: .solid)
        return p
    }
}
#endif
