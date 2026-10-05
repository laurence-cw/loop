import Foundation

/// What each section screen last showed, kept for the rest of the day so opening it again shows it at
/// once while a fresh read runs underneath, instead of an empty screen until that read lands. On a strap
/// with a heavy store a full read takes seconds, which looked like nothing was there.
///
/// Memory only, never written anywhere. A value from an earlier day is never shown.
@MainActor
enum LoopShown {
    private struct Entry {
        let value: Any
        let day: Date
    }
    private static var entries: [ObjectIdentifier: Entry] = [:]

    static func last<T>(_ type: T.Type, now: Date = .now) -> T? {
        guard let e = entries[ObjectIdentifier(type)], Calendar.current.isDate(e.day, inSameDayAs: now) else { return nil }
        return e.value as? T
    }

    static func keep<T>(_ value: T, now: Date = .now) {
        entries[ObjectIdentifier(T.self)] = Entry(value: value, day: now)
    }

    /// Reads every section once, quietly, so the first tap into any of them is already filled in. Called
    /// from Home after its own read, once per launch; the screens still re-read when opened.
    static func warm(repo: Repository, profile: ProfileStore, today: LoopToday) async {
        if last(LoopSleep.self) == nil { keep(await LoopSleepReader.read(repo: repo, today: today)) }
        if last(LoopRecoveryInsights.self) == nil {
            keep(LoopRecoveryReader.read(repo: repo))
            keep(await LoopRecoveryInsightsReader.read(repo: repo, today: today))
        }
        if last(LoopActivity.self) == nil { keep(await LoopActivityReader.read(repo: repo, profile: profile, today: today)) }
        if last(LoopWeek.self) == nil { keep(await LoopWeekReader.read(repo: repo, today: today)) }
    }
}
