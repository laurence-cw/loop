import Foundation
import StrandAnalytics
import WhoopProtocol
import WhoopStore

/// Today's activity and this week's, read through Noop's stored rows and Noop's own effort scorer.
struct LoopActivity: Equatable {
    struct Hour: Equatable {
        /// Hour of the day, 6...23.
        let hour: Int
        /// Effort added during this hour on Noop's 0-100 axis: today's effort up to the end of the hour
        /// minus today's effort up to its start. Nil when the strap recorded nothing that hour.
        let added: Double?
        /// The hour hasn't happened yet.
        let future: Bool
    }

    struct Workout: Equatable, Identifiable {
        let id: String
        let name: String
        let start: Int
        let minutes: Int
        let effort: Int?
    }

    struct Day: Equatable {
        let day: String
        let effort: Double?
        let steps: Int?
        var kcal: Double? = nil
    }

    /// Minutes in each of Noop's five heart-rate zones today, zone 1 first.
    var zoneMinutes: [Double] = []
    /// Each zone's lower edge in bpm, zone 1 first, and the max heart rate they come from.
    var zoneFloors: [Int] = []
    var maxHR: Int?
    /// Noop's whole-day calorie estimate from heart rate, nil until there's enough of the day.
    var kcalToday: Double?

    var hours: [Hour] = []
    var workouts: [Workout] = []
    /// Monday to Sunday of this week. Days still to come are omitted.
    var week: [Day] = []

    static let empty = LoopActivity()

    /// The biggest single activity today, when it clearly carried the day (at least 60% of the effort).
    func mainActivity(dayEffort: Double?) -> Workout? {
        guard let dayEffort, dayEffort > 0,
              let top = workouts.max(by: { ($0.effort ?? 0) < ($1.effort ?? 0) }),
              let e = top.effort, Double(e) >= dayEffort * 0.6 else { return nil }
        return top
    }
}

@MainActor
enum LoopActivityReader {
    static let firstHour = 6
    static let lastHour = 23

    static func kcal(_ v: Double?) -> Double? { v.flatMap { $0 >= 100 ? $0 : nil } }

    static func read(repo: Repository, profile: ProfileStore, today: LoopToday) async -> LoopActivity {
        var out = LoopActivity()
        let cal = Calendar.current
        let logicalToday = Repository.logicalDay(Date())
        let dayStart = cal.startOfDay(for: logicalToday)
        let now = Int(Date().timeIntervalSince1970)
        let todayKey = repo.today?.day ?? Repository.localDayKey(logicalToday)
        let day = repo.today ?? repo.days.last(where: { $0.day == todayKey })

        // Effort through the day: the same scorer, parameters and window Home's live effort uses,
        // asked cumulatively hour by hour, so each bar is the effort that hour added.
        let windowStart = Int(dayStart.timeIntervalSince1970)
        let hr = await repo.hrSamples(from: windowStart, to: now, limit: 200_000)
        let maxHR = profile.effortHRmax
        let restHR = day?.restingHr.map(Double.init) ?? StrainScorer.defaultRestingHR
        func effort(upTo ts: Int) -> Double {
            let slice = hr.prefix { $0.ts < ts }
            return StrainScorer.strain(Array(slice), maxHR: maxHR, restingHR: restHR,
                                       method: PuffinExperiment.effortMethod, sex: profile.sex) ?? 0
        }
        for h in LoopActivityReader.firstHour...LoopActivityReader.lastHour {
            let start = windowStart + h * 3600, end = start + 3600
            guard start <= now else {
                out.hours.append(.init(hour: h, added: nil, future: true))
                continue
            }
            let hasSamples = hr.contains { $0.ts >= start && $0.ts < end }
            let added = hasSamples ? max(effort(upTo: min(end, now)) - effort(upTo: start), 0) : nil
            out.hours.append(.init(hour: h, added: added, future: false))
        }

        // Heart-rate zones: Noop's %HRmax model from the wearer's age (or Noop's max-HR override).
        let zoneSet = HRZones.zones(age: Double(profile.age),
                                    maxHROverride: profile.hrMaxOverride > 0 ? Double(profile.hrMaxOverride) : nil)
        if !hr.isEmpty {
            out.zoneMinutes = HRZones.timeInZone(hr, zoneSet: zoneSet).seconds.map { $0 / 60 }
        }
        out.zoneFloors = zoneSet.zones.map { Int($0.lower.rounded()) }
        out.maxHR = Int(zoneSet.maxHR.rounded())

        // Calories: Noop's stored estimate. A figure under 100 kcal is a day barely begun or a partial
        // write, not a reading worth showing.
        out.kcalToday = LoopActivityReader.kcal(day?.activeKcalEst)

        // Today's workouts, detected or recorded, oldest first.
        let rows = await repo.workoutRows(days: 2)
        out.workouts = rows
            // Today's, and only ones that have already started.
            .filter { $0.startTs >= windowStart && $0.startTs <= now }
            .sorted { $0.startTs < $1.startTs }
            .map { r in
                let mins = Int(((r.durationS ?? Double(r.endTs - r.startTs)) / 60).rounded())
                return .init(id: "\(r.startTs)|\(r.sport)", name: WorkoutSource.displaySport(r.sport),
                             start: r.startTs, minutes: mins, effort: r.strain.map { Int($0.rounded()) })
            }

        // This week, Monday first. Today uses the same live effort and steps as Home.
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = cal.timeZone
        let weekStart = iso.dateInterval(of: .weekOfYear, for: logicalToday)?.start ?? logicalToday
        let stepsEst = await repo.exploreSeries(key: "steps_est", source: "my-whoop")
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: offset, to: weekStart), d <= logicalToday else { break }
            let key = Repository.localDayKey(d)
            if key == todayKey {
                out.week.append(.init(day: key, effort: today.effort, steps: today.steps, kcal: out.kcalToday))
            } else {
                let row = repo.days.last(where: { $0.day == key })
                let steps = row?.steps ?? stepsEst.last(where: { $0.day == key }).map { Int($0.value.rounded()) }
                out.week.append(.init(day: key, effort: row?.strain, steps: steps, kcal: kcal(row?.activeKcalEst)))
            }
        }
        return out
    }
}
