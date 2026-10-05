import Foundation
import UserNotifications

/// "Charge your strap": when Loop nudges in the app, and the notification permission Noop's own battery
/// alerts need.
///
/// The alerts themselves are Noop's (`BatteryNotifier`: low at 15%, critical at 12%, "won't last the
/// night" near bedtime, and a last-seen-low warning for a strap out of contact). They are on by default,
/// but they post only when the app may send notifications, and Noop asked for that from its own settings
/// screen, which Loop does not show. A field WHOOP 4.0 ran flat overnight twice without a word. Loop
/// asks once, from a card that says what it's for, and shows its own evening card in the app.
enum LoopCharge {
    /// At or below this the evening card shows. Above Noop's 15% alert, so the card comes first: a strap
    /// at 30% at 9pm does not reliably see the morning.
    static let nudgeAtOrBelowPct: Double = 30
    /// The evening starts here (local hour). Earlier in the day there's time to charge later.
    static let eveningFromHour = 18

    /// Whether Home shows "Charge your strap before bed" right now. Only for a WHOOP reading (Noop's
    /// battery field can carry another device's charge), only when it isn't already charging, and only
    /// in the evening, from 6pm until 2am, the hours a teenager is plausibly still up.
    static func showsEveningCard(now: Date, pct: Double?, charging: Bool?, readingIsWhoop: Bool,
                                 cal: Calendar = .current) -> Bool {
        guard readingIsWhoop, let pct, charging != true, pct <= nudgeAtOrBelowPct else { return false }
        let hour = cal.component(.hour, from: now)
        return hour >= eveningFromHour || hour < 2
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Shows the system prompt (only ever while the status is still undecided) and reports the outcome.
    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
