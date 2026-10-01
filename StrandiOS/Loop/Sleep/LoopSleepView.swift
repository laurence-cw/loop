import SwiftUI

/// Sleep, one tap in from Home. Headline: hours slept against hours needed. Then the stages, time
/// awake and sleep quality. Then bedtime and wake-time consistency across the week.
struct LoopSleepView: View {
    @Binding var today: LoopToday

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var repo: Repository
    @State private var sleep = LoopSleep.empty
    @State private var loaded = false
    @State private var titleScrolledAway = false

    private var isWhoop5: Bool { LoopStrap.isWhoop5(model: model) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text("Sleep").font(LoopFont.title).foregroundStyle(LoopColor.text)
                } icon: {
                    Image(systemName: "moon.fill").font(.title3).foregroundStyle(LoopColor.signal)
                }
                .padding(.top, LoopSpace.xs)
                .accessibilityAddTraits(.isHeader)

                LoopSleepRing(asleepMin: today.sleepMin, needMin: today.sleepNeedMin, score: today.sleepScore)
                    .frame(width: 220, height: 220)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LoopSpace.xl)

                Text(headline)
                    .font(LoopFont.sentence)
                    .foregroundStyle(LoopColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                if loaded { detail }
            }
            .padding(.horizontal, LoopSpace.edge)
            .padding(.bottom, LoopSpace.xl)
        }
        .modifier(LoopTitleOnScroll(scrolledAway: $titleScrolledAway))
        .scrollIndicators(.hidden)
        .background(LoopColor.night.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Sleep")
                    .font(LoopFont.inlineTitle)
                    .foregroundStyle(LoopColor.text)
                    .opacity(titleScrolledAway ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: titleScrolledAway)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .modifier(LoopSoftTopEdge())
        .tint(LoopColor.text)
        .task(id: repo.refreshSeq) {
            sleep = await LoopSleepReader.read(repo: repo, today: today, isWhoop5: isWhoop5)
            #if DEBUG
            if CommandLine.arguments.contains("--loop-preview-whoop5") { sleep.unreliableStages = true }
            if CommandLine.arguments.contains("--loop-preview-missing-night"), sleep.week.count > 1 {
                sleep.week[1] = .init(day: sleep.week[1].day, bed: nil, wake: nil)
            }
            #endif
            withAnimation(.easeOut(duration: 0.3)) { loaded = true }
        }
    }

    /// Shown only once read, so real data never flashes as "No data" first.
    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoopStagesCard(sleep: sleep)
                .padding(.top, LoopSpace.l)

            VStack(spacing: LoopSpace.s) {
                LoopValueRow(title: "Time awake",
                             value: sleep.awakeMin.map { LoopFormat.duration($0 * 60) },
                             explainer: "Waking a few times a night is normal.")
                LoopValueRow(title: "Sleep quality",
                             value: sleep.qualityPct.map { "\($0)%" },
                             explainer: "How much of your time in bed you were actually asleep.",
                             divider: false)
            }
            .padding(.top, LoopSpace.xl)

            LoopSleepWeekCard(week: sleep.week)
                .padding(.top, LoopSpace.xl)
        }
        .transition(.opacity)
    }

    // MARK: Words

    private var headline: String {
        guard let asleep = today.sleepMin else { return "No sleep recorded last night. Was the strap off?" }
        // The ring already shows the hours, so the sentence carries only the meaning.
        if asleep >= today.sleepNeedMin { return "Enough sleep. That's why today feels easy." }
        if asleep >= today.sleepNeedMin - 45 { return "Close to what you need." }
        return "Short night. Tonight, aim for an earlier one."
    }
}

// MARK: - Pieces

/// The headline: one blue ring filling towards the night's need, the hours in the middle.
struct LoopSleepRing: View {
    let asleepMin: Double?
    let needMin: Double
    let score: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44
    @State private var shown: Double = 0

    private var fraction: Double {
        guard let asleepMin else { return 0 }
        return min(asleepMin / max(needMin, 1), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(LoopColor.line, lineWidth: LoopShape.arcStroke)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(LoopColor.signal, style: StrokeStyle(lineWidth: LoopShape.arcStroke, lineCap: .round))
                // Starts at the bottom and fills up the left, the way Home's Sleep arc fills the tank.
                .rotationEffect(.degrees(90))
                .opacity(shown > 0.001 ? 1 : 0)
            VStack(spacing: 2) {
                Text(asleepMin.map { LoopFormat.duration($0 * 60) } ?? "No data")
                    .font(asleepMin == nil ? LoopFont.word(size: 22) : LoopFont.number(size: heroSize))
                    .foregroundStyle(asleepMin == nil ? LoopColor.muted : LoopColor.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: asleepMin ?? 0))
                Text("of \(LoopFormat.duration(needMin * 60)) needed")
                    .font(LoopFont.meta)
                    .foregroundStyle(LoopColor.muted)
                if let score {
                    Text(ScoreWord.word(for: score))
                        .font(LoopFont.word(size: 24))
                        .foregroundStyle(LoopColor.signal)
                        .padding(.top, LoopSpace.xs)
                }
            }
            .padding(.horizontal, LoopSpace.l)
        }
        .padding(LoopShape.arcStroke / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear { settle() }
        .onChange(of: fraction) { _, _ in settle() }
    }

    private func settle() {
        if reduceMotion { shown = fraction } else { withAnimation(LoopMotion.fill) { shown = fraction } }
    }

    private var accessibilityText: String {
        guard let asleepMin else { return "Sleep: no data for last night" }
        var t = "Slept \(LoopFormat.duration(asleepMin * 60)) of \(LoopFormat.duration(needMin * 60)) needed"
        if let score { t += ", \(ScoreWord.word(for: score))" }
        return t
    }
}

/// Light, deep and dream sleep as one bar split by share of the night, then one line each.
struct LoopStagesCard: View {
    let sleep: LoopSleep

    private struct Stage: Identifiable {
        let id: String
        let minutes: Double
        let colour: Color
        let explainer: String
    }

    private var stages: [Stage] {
        [
            Stage(id: "Light sleep", minutes: sleep.lightMin ?? 0, colour: LoopColor.stageLight,
                  explainer: "Most of the night. Easy to wake from."),
            Stage(id: "Deep sleep", minutes: sleep.deepMin ?? 0, colour: LoopColor.stageDeep,
                  explainer: "When your body repairs muscles."),
            Stage(id: "Dream sleep", minutes: sleep.dreamMin ?? 0, colour: LoopColor.stageDream,
                  explainer: "When your brain sorts out the day."),
        ]
    }

    /// Whole minutes per stage that add up exactly to the night's total, so the parts never
    /// disagree with the headline (largest-remainder rounding over the stages' shares).
    private var rounded: [String: Int] {
        let raw = stages.map(\.minutes)
        let sum = raw.reduce(0, +)
        guard sum > 0 else { return [:] }
        let total = Int((sleep.asleepMin ?? sum).rounded())
        let exact = raw.map { $0 / sum * Double(total) }
        var whole = exact.map { Int($0.rounded(.down)) }
        let order = exact.indices.sorted { (exact[$0] - Double(whole[$0])) > (exact[$1] - Double(whole[$1])) }
        for i in order.prefix(max(total - whole.reduce(0, +), 0)) { whole[i] += 1 }
        return Dictionary(uniqueKeysWithValues: zip(stages.map(\.id), whole))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Stages")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)

            if sleep.unreliableStages {
                Text("Not reliable on this strap yet.")
                    .font(LoopFont.explainer)
                    .foregroundStyle(LoopColor.muted)
            } else if sleep.hasStages {
                bar
                VStack(spacing: LoopSpace.s) {
                    ForEach(stages) { stage in
                        HStack(alignment: .firstTextBaseline, spacing: LoopSpace.s) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stage.colour)
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stage.id)
                                    .font(LoopFont.rowTitle)
                                    .foregroundStyle(LoopColor.text)
                                Text(stage.explainer)
                                    .font(LoopFont.explainer)
                                    .foregroundStyle(LoopColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: LoopSpace.xs)
                            Text(LoopFormat.duration(Double(rounded[stage.id] ?? 0) * 60))
                                .font(LoopFont.rowValue)
                                .foregroundStyle(LoopColor.text)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                Text("No stages for last night.")
                    .font(LoopFont.explainer)
                    .foregroundStyle(LoopColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.signal))
    }

    private var bar: some View {
        let total = max(stages.map(\.minutes).reduce(0, +), 1)
        return GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(stages) { stage in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stage.colour)
                        .frame(width: max((geo.size.width - 6) * stage.minutes / total, 0))
                }
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

/// A title, its value, and a one-line explainer. A quiet line, not a card.
struct LoopValueRow: View {
    let title: String
    let value: String?
    let explainer: String
    var divider: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.text)
                Spacer(minLength: LoopSpace.xs)
                Text(value ?? "No data")
                    .font(LoopFont.rowValue)
                    .foregroundStyle(value == nil ? LoopColor.muted : LoopColor.text)
            }
            Text(explainer)
                .font(LoopFont.explainer)
                .foregroundStyle(LoopColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            if divider {
                Rectangle().fill(LoopColor.line).frame(height: 1).padding(.top, LoopSpace.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Monday to Sunday: each night drawn from bedtime (top) to wake time (bottom), so a steady week
/// lines up. Nights with nothing recorded are labelled "no data", never drawn as zero.
struct LoopSleepWeekCard: View {
    let week: [LoopSleep.Night]

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    /// Minutes since the previous noon, so 10pm is 600 and 7am is 1140.
    private func minutesFromNoon(_ ts: Int) -> Double {
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
        return m >= 12 * 60 ? m - 12 * 60 : m + 12 * 60
    }

    private var recorded: [(bed: Double, wake: Double)] {
        week.compactMap { n in
            guard let b = n.bed, let w = n.wake else { return nil }
            return (minutesFromNoon(b), minutesFromNoon(w))
        }
    }

    /// The axis: earliest bedtime to latest wake, padded, never narrower than 9pm–9am.
    private var axis: (top: Double, bottom: Double) {
        let top = min(recorded.map(\.bed).min() ?? 540, 540) - 30
        let bottom = max(recorded.map(\.wake).max() ?? 1260, 1260) + 30
        return (top, bottom)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("This week")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            Text(consistencyLine)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
                .fixedSize(horizontal: false, vertical: true)

            chart
                .padding(.top, LoopSpace.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.signal))
    }

    private var chart: some View {
        let a = axis
        // Round-hour labels inside the axis, placed by the same scale the bars use.
        let topLabel = (a.top / 60).rounded(.up) * 60
        let bottomLabel = (a.bottom / 60).rounded(.down) * 60
        let plotHeight: CGFloat = 150
        return VStack(spacing: LoopSpace.xs) {
            HStack(spacing: LoopSpace.xs) {
                GeometryReader { geo in
                    let scale: (Double) -> CGFloat = { m in CGFloat((m - a.top) / (a.bottom - a.top)) * geo.size.height }
                    ZStack(alignment: .topLeading) {
                        Text(clockLabel(topLabel)).font(LoopFont.meta).foregroundStyle(LoopColor.muted)
                            .position(x: 20, y: scale(topLabel))
                        Text(clockLabel(bottomLabel)).font(LoopFont.meta).foregroundStyle(LoopColor.muted)
                            .position(x: 20, y: scale(bottomLabel))
                    }
                }
                .frame(width: 40)
                ForEach(0..<7, id: \.self) { i in
                    GeometryReader { geo in
                        let h = geo.size.height
                        let scale: (Double) -> CGFloat = { m in CGFloat((m - a.top) / (a.bottom - a.top)) * h }
                        ZStack(alignment: .top) {
                            Capsule().fill(LoopColor.line.opacity(0.5)).frame(width: 2)
                                .frame(maxHeight: .infinity)
                            if i < week.count, let b = week[i].bed, let w = week[i].wake {
                                let top = scale(minutesFromNoon(b)), bottom = scale(minutesFromNoon(w))
                                Capsule()
                                    .fill(LoopColor.signal)
                                    .frame(width: 10, height: max(bottom - top, 10))
                                    .offset(y: top)
                            } else if i < week.count {
                                // A past night with nothing recorded: said plainly, never drawn as zero.
                                Text("No\ndata")
                                    .font(LoopFont.meta)
                                    .foregroundStyle(LoopColor.muted)
                                    .multilineTextAlignment(.center)
                                    .fixedSize()
                                    .padding(.vertical, 4)
                                    .background(LoopColor.surface)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: plotHeight)
            HStack(spacing: LoopSpace.xs) {
                Color.clear.frame(width: 40, height: 1)
                ForEach(0..<7, id: \.self) { i in
                    Text(dayLetters[i])
                        .font(LoopFont.meta)
                        .foregroundStyle(i < week.count ? LoopColor.text : LoopColor.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibility)
    }

    private func clockLabel(_ minutesFromNoon: Double) -> String {
        let m = (Int(minutesFromNoon.rounded()) + 12 * 60) % (24 * 60)
        let h = m / 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12)\(h < 12 ? "am" : "pm")"
    }

    /// One sentence on how steady bedtimes and wake times were. Never a telling-off.
    private var consistencyLine: String {
        guard recorded.count >= 3 else {
            return "A few more nights and you'll see how steady your bedtimes and wake times are."
        }
        let bedSpread = spread(recorded.map(\.bed)), wakeSpread = spread(recorded.map(\.wake))
        let steady = 45.0
        switch (bedSpread <= steady, wakeSpread <= steady) {
        case (true, true):
            return "Bedtimes and wake times within \(phrase(max(bedSpread, wakeSpread))) all week. Nice and steady."
        case (true, false):
            return "Steady bedtimes. Wake times moved around by \(phrase(wakeSpread))."
        case (false, true):
            return "Steady wake times. Bedtimes moved around by \(phrase(bedSpread))."
        case (false, false):
            return "Bedtimes moved by \(phrase(bedSpread)) and wake times by \(phrase(wakeSpread)) this week."
        }
    }

    private func spread(_ minutes: [Double]) -> Double {
        (minutes.max() ?? 0) - (minutes.min() ?? 0)
    }

    private func phrase(_ minutes: Double) -> String {
        minutes < 60 ? "\(Int(minutes.rounded())) minutes" : LoopFormat.duration(minutes * 60)
    }

    private var chartAccessibility: String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return week.enumerated().map { i, n in
            guard let b = n.bed, let w = n.wake else { return "\(names[i]): no data" }
            return "\(names[i]): \(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(b)))) to \(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(w))))"
        }.joined(separator: ". ")
    }
}
