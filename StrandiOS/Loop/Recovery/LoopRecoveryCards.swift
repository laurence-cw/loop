import SwiftUI
import StrandAnalytics

/// What moved today's score: one sentence naming the biggest effect, then each term as a bar growing
/// left (held it back) or right (helped) from the middle, by its real share of the score.
struct LoopDriversCard: View {
    let drivers: [LoopRecoveryInsights.Driver]
    /// Today's Recovery colour, for the "helped" side.
    let tint: Color

    private var shown: [LoopRecoveryInsights.Driver] { Array(drivers.prefix(4)) }
    private var maxAbs: Double { Double(max(shown.map { abs($0.points) }.max() ?? 1, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("What moved it")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            Text(sentence)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: LoopSpace.s) {
                ForEach(Array(shown.enumerated()), id: \.element.name) { i, d in
                    row(d, index: i)
                }
            }
            .padding(.top, LoopSpace.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: tint))
    }

    private func row(_ d: LoopRecoveryInsights.Driver, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(d.name)
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.text)
                Spacer(minLength: LoopSpace.xs)
                Text(effect(d.points))
                    .font(LoopFont.meta)
                    .foregroundStyle(d.points > 0 ? tint : LoopColor.muted)
            }
            GeometryReader { geo in
                let half = geo.size.width / 2
                let w = max(half * CGFloat(Double(abs(d.points)) / maxAbs), d.points == 0 ? 0 : 3)
                ZStack(alignment: .leading) {
                    Capsule().fill(LoopColor.line).frame(height: 6)
                    Rectangle().fill(LoopColor.muted.opacity(0.6)).frame(width: 1, height: 12)
                        .offset(x: half)
                    Capsule()
                        .fill(d.points >= 0 ? tint : LoopColor.muted)
                        .frame(width: w, height: 6)
                        .loopBuildIn(index, from: d.points >= 0 ? .leading : .trailing, stagger: 0.1)
                        .offset(x: d.points >= 0 ? half : half - w)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 12)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func effect(_ p: Int) -> String {
        if p == 0 { return "No effect" }
        return p > 0 ? "Helped, +\(p)" : "Held it back, \(p)"
    }

    private var sentence: String {
        guard let top = shown.first, abs(top.points) >= 3 else {
            return "Nothing stood out. A normal night for you."
        }
        let what = top.name.lowercased()
        return top.points > 0 ? "Mostly your \(what) helped." : "Mostly your \(what) held it back."
    }
}

/// Stress through the day: one bar per hour from 6am, as tall as Noop's 0-3 stress reading. Hours spent
/// moving are marked as moving rather than scored, as Noop does (exercise isn't stress).
struct LoopStressCard: View {
    let hours: [(hour: Int, level: Double?, moving: Bool)]
    let dayMean: Double?
    let peakHour: Int?

    private var span: [Int] { Array(6...23) }
    /// Nothing to draw until at least one hour has a reading (or was spent moving).
    private var hasData: Bool { hours.contains { $0.level != nil || $0.moving } }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Stress through the day")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            Text(summary)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
                .fixedSize(horizontal: false, vertical: true)

            if hasData {
            VStack(spacing: LoopSpace.xs) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(span, id: \.self) { h in bar(for: h) }
                }
                .frame(height: 72)
                Rectangle().fill(LoopColor.line).frame(height: 1)
                HStack {
                    Text("6am")
                    Spacer()
                    Text("12am")
                }
                .font(LoopFont.meta)
                .foregroundStyle(LoopColor.muted)
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width, y = geo.size.height / 2
                        Text("12pm").position(x: w * 6 / 18, y: y)
                        Text("6pm").position(x: w * 12 / 18, y: y)
                    }
                    .font(LoopFont.meta)
                    .foregroundStyle(LoopColor.muted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)

            HStack(spacing: LoopSpace.s) {
                legend(LoopColor.text.opacity(0.85), "Busy")
                legend(LoopColor.text.opacity(0.3), "Calm")
                legend(LoopColor.pulse.opacity(0.6), "Moving")
            }
            .accessibilityHidden(true)
            }

            Text("From your heart rate and heart variability through the day.")
                .font(LoopFont.explainer)
                .foregroundStyle(LoopColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.muted))
    }

    @ViewBuilder
    private func bar(for h: Int) -> some View {
        let point = hours.first { $0.hour == h }
        if let point, point.moving {
            RoundedRectangle(cornerRadius: 3)
                .fill(LoopColor.pulse.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 8)
                .loopBuildIn(h - 6, stagger: 0.03)
        } else if let level = point?.level {
            let f = min(max(level / 3, 0), 1)
            RoundedRectangle(cornerRadius: 3)
                .fill(LoopColor.text.opacity(0.3 + 0.55 * f))
                .frame(maxWidth: .infinity)
                .frame(height: max(72 * f, 4))
                .loopBuildIn(h - 6, stagger: 0.03)
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    private func legend(_ colour: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 10, height: 10)
            Text(text).font(LoopFont.meta).foregroundStyle(LoopColor.muted)
        }
    }

    /// Noop's bands: under 1 calm, around 1.5 your usual, over 2 high.
    private var summary: String {
        guard let mean = dayMean, hours.contains(where: { $0.level != nil }) else {
            return "Not enough heart data from today yet."
        }
        let day = mean < 1 ? "A calm day so far." : (mean < 2 ? "A normal day so far." : "A busy day so far.")
        if let p = peakHour, let lvl = hours.first(where: { $0.hour == p })?.level, lvl >= 2 {
            return "\(day) Busiest around \(LoopDayEffortCard.hourLabel(p))."
        }
        return day
    }
}

/// Tomorrow: Noop's evening estimate of tomorrow's Recovery, if tonight's bedtime is kept.
struct LoopForecastCard: View {
    let forecast: RecoveryForecast
    let needMin: Double

    var body: some View {
        let band = RecoveryBand(score: Int(forecast.charge.rounded()))
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let plan = LoopTonightPlan.make(now: context.date, needMin: needMin,
                                            wakeMinutes: WindDownNudge.wakeMinutes(forWeekday:))
            VStack(alignment: .leading, spacing: LoopSpace.s) {
                Text("Tomorrow")
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.muted)
                HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
                    Text("Likely \(band.word)")
                        .font(LoopFont.word(size: 28))
                        .foregroundStyle(band.colour)
                    Text("\(Int(forecast.low.rounded()))–\(Int(forecast.high.rounded()))")
                        .font(LoopFont.rowValue)
                        .foregroundStyle(LoopColor.muted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(condition(plan))
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("An estimate from your recent scores and today's effort. Tomorrow's real score comes from tonight's sleep.")
                    .font(LoopFont.explainer)
                    .foregroundStyle(LoopColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LoopSpace.cardPadding)
            .background(LoopCardBackground(glow: band.colour))
            .accessibilityElement(children: .combine)
        }
    }

    private func condition(_ plan: LoopTonightPlan?) -> String {
        guard let plan, !plan.late else { return "If you get a full night from here." }
        return "If you're asleep by \(LoopFormat.clock(plan.asleepBy)) tonight."
    }
}
