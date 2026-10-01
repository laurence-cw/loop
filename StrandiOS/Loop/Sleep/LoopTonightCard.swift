import SwiftUI

/// Tonight: when to be asleep by for the next wake-up set in Settings, and the sleep debt to catch up.
/// Re-read every minute, so the plan is right whenever the card is looked at.
struct LoopTonightCard: View {
    let needMin: Double
    let debtMin: Double
    /// Nights the debt estimate rests on; too few and it says so instead of a number.
    let debtNights: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let plan = LoopTonightPlan.make(now: context.date, needMin: needMin,
                                            wakeMinutes: WindDownNudge.wakeMinutes(forWeekday:))
            VStack(alignment: .leading, spacing: LoopSpace.s) {
                Text("Tonight")
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.muted)

                if let plan {
                    VStack(alignment: .leading, spacing: LoopSpace.xs) {
                        // A clock time, so proportional digits: "11:00pm", not a monospaced "1 1:00pm".
                        Text(plan.late ? "Sleep now" : LoopFormat.clock(plan.asleepBy))
                            .font(.system(size: 40, weight: .light).width(.expanded))
                            .foregroundStyle(LoopColor.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(planLine(plan, now: context.date))
                            .font(LoopFont.body)
                            .foregroundStyle(LoopColor.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }

                Rectangle().fill(LoopColor.line).frame(height: 1)

                VStack(alignment: .leading, spacing: LoopSpace.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Sleep debt")
                            .font(LoopFont.rowTitle)
                            .foregroundStyle(LoopColor.text)
                        Spacer(minLength: LoopSpace.xs)
                        Text(debtValue)
                            .font(LoopFont.rowValue)
                            .foregroundStyle(debtShown && debtMin >= 10 ? LoopColor.signal : LoopColor.text)
                    }
                    Text(debtLine)
                        .font(LoopFont.explainer)
                        .foregroundStyle(LoopColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LoopSpace.cardPadding)
            .background(LoopCardBackground(glow: LoopColor.signal))
        }
    }

    // MARK: Words

    private var needText: String { LoopFormat.duration(needMin * 60) }

    private func planLine(_ plan: LoopTonightPlan, now: Date) -> String {
        let wake = "\(LoopFormat.clock(plan.wake)) alarm\(Self.whenSuffix(plan.wake, now: now))"
        if plan.late {
            return "You can still get \(LoopFormat.duration(plan.availableMin * 60)) before your \(wake)."
        }
        return "Be asleep by then to get your \(needText) before your \(wake)."
    }

    /// " tomorrow", " on Saturday", or nothing when the wake-up is later today.
    static func whenSuffix(_ wake: Date, now: Date, cal: Calendar = .current) -> String {
        if cal.isDate(wake, inSameDayAs: now) { return "" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(wake, inSameDayAs: t) { return " tomorrow" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE"
        return " on \(f.string(from: wake))"
    }

    private var debtShown: Bool { debtNights >= 3 }

    private var debtValue: String {
        guard debtShown else { return "Learning" }
        return debtMin < 10 ? "None" : LoopFormat.duration(debtMin * 60)
    }

    /// Noop's ledger: sleeping need + debt clears it; sleeping just the need carries 55% of it forward,
    /// so a normal full night roughly halves it.
    private var debtLine: String {
        guard debtShown else { return "A few more nights and Loop can work this out." }
        if debtMin < 10 { return "You've been getting what you need. Nice." }
        if debtMin <= 90 {
            return "Sleep \(LoopFormat.duration((needMin + debtMin) * 60)) tonight and it's gone."
        }
        return "A full \(needText) night tonight cuts it roughly in half."
    }
}
