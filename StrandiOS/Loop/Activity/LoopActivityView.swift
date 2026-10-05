import SwiftUI

/// Activity, one tap in from Home. Headline: today's effort and steps. Then live heart rate and the
/// day's heart-rate line, effort through the day with its peaks, heart-rate zones, today's activities, calories burned, and the week.
struct LoopActivityView: View {
    @Binding var today: LoopToday

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @State private var activity = LoopShown.last(LoopActivity.self) ?? .empty
    @State private var loaded = LoopShown.last(LoopActivity.self) != nil
    @State private var titleScrolledAway = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text("Activity").font(LoopFont.title).foregroundStyle(LoopColor.text)
                } icon: {
                    Image(systemName: "figure.walk").font(.title3).foregroundStyle(LoopColor.pulse)
                }
                .padding(.top, LoopSpace.xs)
                .accessibilityAddTraits(.isHeader)

                LoopEffortRing(effort: today.effort, steps: today.steps)
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
            // The Loop mark sits in the bar until the page title scrolls away, then hands over to it.
            ToolbarItem(placement: .principal) {
                ZStack {
                    LoopMark(size: 30)
                        .opacity(titleScrolledAway ? 0 : 1)
                    Text("Activity")
                        .font(LoopFont.inlineTitle)
                        .foregroundStyle(LoopColor.text)
                        .opacity(titleScrolledAway ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.2), value: titleScrolledAway)
            }
            LoopGaugesToolbarItem()
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .modifier(LoopSoftTopEdge())
        .tint(LoopColor.text)
        .task(id: repo.refreshSeq) {
            activity = await LoopActivityReader.read(repo: repo, profile: profile, today: today)
            #if DEBUG
            if CommandLine.arguments.contains("--loop-preview-activity") { activity = LoopActivity.previewSchoolDay() }
            #endif
            LoopShown.keep(activity)
            withAnimation(.easeOut(duration: 0.15)) { loaded = true }
        }
    }

    /// Shown only once read, so real data never flashes as "No data" first.
    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            #if DEBUG
            if CommandLine.arguments.contains("--loop-preview-lower-cards") {
                LoopZonesCard(minutes: activity.zoneMinutes, floors: activity.zoneFloors, maxHR: activity.maxHR)
                    .padding(.top, LoopSpace.l)
                LoopCaloriesCard(today: activity.kcalToday, week: activity.week).padding(.top, LoopSpace.s)
            }
            #endif
            LoopHeartCard()
                .padding(.top, LoopSpace.l)

            LoopDayEffortCard(hours: activity.hours)
                .padding(.top, LoopSpace.s)

            LoopZonesCard(minutes: activity.zoneMinutes, floors: activity.zoneFloors, maxHR: activity.maxHR)
                .padding(.top, LoopSpace.s)

            LoopWorkoutsList(workouts: activity.workouts)
                .padding(.top, LoopSpace.xl)

            LoopCaloriesCard(today: activity.kcalToday, week: activity.week)
                .padding(.top, LoopSpace.xl)

            LoopActivityWeekCard(week: activity.week)
                .padding(.top, LoopSpace.xl)
        }
        .transition(.opacity)
    }

    private var headline: String {
        guard let e = today.effort else { return "No effort recorded yet today." }
        let main = activity.mainActivity(dayEffort: e)
        switch Int(e.rounded()) {
        case 67...:
            return main.map { "Big effort today. \($0.name) did most of it." } ?? "Big effort today."
        case 34...66:
            return main.map { "Solid day so far. \($0.name) did most of it." } ?? "Solid day so far."
        default:
            return "Quiet day so far. A walk would help."
        }
    }
}

// MARK: - Pieces

/// The headline: one magenta ring spending down from the top, the way Home's Activity arc does.
struct LoopEffortRing: View {
    let effort: Double?
    let steps: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 36
    @State private var shown: Double = 0

    private var fraction: Double { min(max((effort ?? 0) / 100, 0), 1) }
    private var score: Int? { effort.map { Int($0.rounded()) } }

    var body: some View {
        ZStack {
            Circle().stroke(LoopColor.line, lineWidth: LoopShape.arcStroke)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(LoopColor.pulse, style: StrokeStyle(lineWidth: LoopShape.arcStroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(shown > 0.001 ? 1 : 0)
            VStack(spacing: 2) {
                if let score {
                    (Text("\(score)").font(LoopFont.number(size: heroSize)).foregroundStyle(LoopColor.text)
                     + Text("/100").font(LoopFont.meta).foregroundStyle(LoopColor.muted))
                        .contentTransition(.numericText(value: Double(score)))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(ScoreWord.word(for: score))
                        .font(LoopFont.word(size: 20))
                        .foregroundStyle(LoopColor.pulse)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("No data")
                        .font(LoopFont.word(size: 18))
                        .foregroundStyle(LoopColor.muted)
                }
                Text(steps.map { "\(LoopFormat.steps($0)) steps" } ?? "No steps yet")
                    .font(LoopFont.meta)
                    .foregroundStyle(LoopColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, LoopSpace.xs)
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
        var parts: [String] = []
        if let score { parts.append("Effort \(score) out of 100, \(ScoreWord.word(for: score))") }
        else { parts.append("Effort: no data yet") }
        if let steps { parts.append("\(LoopFormat.steps(steps)) steps") }
        return parts.joined(separator: ". ")
    }
}

/// Effort through the day, 6am to midnight: one bar per hour for the effort that hour added.
/// The day's peaks stand out at full colour; hours with nothing recorded show a grey stub, never zero.
struct LoopDayEffortCard: View {
    let hours: [LoopActivity.Hour]

    private var peak: Double { max(hours.compactMap(\.added).max() ?? 0, 0.01) }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Through the day")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            Text(peakLine)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: LoopSpace.xs) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(hours, id: \.hour) { h in bar(h) }
                }
                .frame(height: 96)
                Rectangle().fill(LoopColor.line).frame(height: 1)
                // 6am and 12am are pinned to the rule's ends; 12pm and 6pm sit on the bars' own scale,
                // a third and two thirds along the 18 hours. The row's height follows the text size.
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
            .accessibilityLabel(peakLine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.pulse))
    }

    @ViewBuilder
    private func bar(_ h: LoopActivity.Hour) -> some View {
        if h.future {
            Color.clear.frame(maxWidth: .infinity)
        } else if let added = h.added {
            let f = added / peak
            RoundedRectangle(cornerRadius: 3)
                .fill(LoopColor.pulse.opacity(f >= 0.6 ? 1 : 0.45))
                .frame(maxWidth: .infinity)
                .frame(height: max(96 * f, 3))
                .loopBuildIn(h.hour - 6, stagger: 0.03)
        } else {
            // Nothing recorded this hour: a grey stub, not a zero.
            RoundedRectangle(cornerRadius: 2)
                .fill(LoopColor.line)
                .frame(maxWidth: .infinity)
                .frame(height: 3)
                .loopBuildIn(h.hour - 6, stagger: 0.03)
        }
    }

    private var peakLine: String {
        let elapsed = hours.filter { !$0.future }
        if !elapsed.isEmpty, elapsed.allSatisfy({ $0.added == nil }) {
            // Effort can come from the stored day row while no heart rate has synced for today's hours.
            return "No hour-by-hour record for today yet."
        }
        let busiest = hours.filter { ($0.added ?? 0) > 0 }.max { ($0.added ?? 0) < ($1.added ?? 0) }
        guard let busiest, (busiest.added ?? 0) >= 2 else { return "No big efforts yet today." }
        return "Busiest around \(Self.hourLabel(busiest.hour))."
    }

    static func hourLabel(_ h: Int) -> String {
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12)\(h < 12 ? "am" : "pm")"
    }
}

/// Today's activities, detected or recorded. A quiet list, not cards.
struct LoopWorkoutsList: View {
    let workouts: [LoopActivity.Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Activities")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            if workouts.isEmpty {
                Text("None picked up yet today.")
                    .font(LoopFont.explainer)
                    .foregroundStyle(LoopColor.muted)
            } else {
                ForEach(Array(workouts.enumerated()), id: \.element.id) { i, w in
                    VStack(alignment: .leading, spacing: LoopSpace.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.name)
                                    .font(LoopFont.rowTitle)
                                    .foregroundStyle(LoopColor.text)
                                Text("\(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(w.start)))) · \(LoopFormat.duration(Double(w.minutes) * 60))")
                                    .font(LoopFont.meta)
                                    .foregroundStyle(LoopColor.muted)
                            }
                            Spacer(minLength: LoopSpace.xs)
                            if let e = w.effort {
                                HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
                                    Text(ScoreWord.word(for: e))
                                        .font(LoopFont.rowValue)
                                        .foregroundStyle(LoopColor.pulse)
                                    Text("\(e)")
                                        .font(LoopFont.rowValue)
                                        .foregroundStyle(LoopColor.text)
                                }
                            }
                        }
                        if i < workouts.count - 1 {
                            Rectangle().fill(LoopColor.line).frame(height: 1).padding(.top, LoopSpace.xs)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// This week, Monday to Sunday: effort in one chart and steps in another, one series each.
struct LoopActivityWeekCard: View {
    let week: [LoopActivity.Day]

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.m) {
            Text("This week")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            LoopWeekBars(title: "Effort", values: week.map { $0.effort }, maxValue: 100,
                         format: { "\(Int($0.rounded()))" })
            LoopWeekBars(title: "Steps", values: week.map { $0.steps.map(Double.init) },
                         maxValue: max(week.compactMap { $0.steps.map(Double.init) }.max() ?? 10_000, 10_000),
                         format: { LoopFormat.steps(Int($0)) })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.pulse))
    }
}

/// One bar per day, Monday to Sunday. Today's bar is full colour; past days are softer.
/// A past day with nothing recorded reads "No data"; days still to come are left empty.
struct LoopWeekBars: View {
    let title: String
    /// Monday onwards, up to today.
    let values: [Double?]
    let maxValue: Double
    let format: (Double) -> String

    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.xs) {
            Text(title).font(LoopFont.rowTitle).foregroundStyle(LoopColor.text)
            HStack(alignment: .bottom, spacing: LoopSpace.xs) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: LoopSpace.xs) {
                        ZStack(alignment: .bottom) {
                            Color.clear
                            if i < values.count {
                                if let v = values[i] {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LoopColor.pulse.opacity(i == values.count - 1 ? 1 : 0.55))
                                        .frame(height: max(CGFloat(v / maxValue) * 64, 3))
                                        .loopBuildIn(i)
                                } else {
                                    Text("No\ndata")
                                        .font(LoopFont.meta)
                                        .foregroundStyle(LoopColor.muted)
                                        .multilineTextAlignment(.center)
                                        .fixedSize()
                                        .loopBuildIn(i)
                                }
                            }
                        }
                        .frame(height: 64)
                        Text(letters[i])
                            .font(LoopFont.meta)
                            .foregroundStyle(i < values.count ? LoopColor.text : LoopColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility)
        }
    }

    private var accessibility: String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return "\(title) this week. " + values.enumerated().map { i, v in
            "\(names[i]): \(v.map(format) ?? "no data")"
        }.joined(separator: ". ")
    }
}

#if DEBUG
extension LoopActivity {
    /// DEBUG-only synthetic school day (PE at 10am, football at lunch, a walk home), for screenshots.
    static func previewSchoolDay() -> LoopActivity {
        let added: [Int: Double] = [7: 2, 8: 4, 9: 1, 10: 9, 11: 2, 12: 13, 13: 3, 14: 1, 15: 5, 16: 2, 17: 1]
        let cal = Calendar.current
        let start = Int(cal.startOfDay(for: Date()).timeIntervalSince1970)
        // Clamped to the clock: no bars or activities after now.
        let nowHour = cal.component(.hour, from: Date())
        let now = Int(Date().timeIntervalSince1970)
        var a = LoopActivity()
        a.hours = (6...23).map { h in
            .init(hour: h, added: h <= nowHour ? (added[h] ?? 0.5) : nil, future: h > nowHour)
        }
        a.workouts = [
            LoopActivity.Workout(id: "pe", name: "PE", start: start + 10 * 3600, minutes: 50, effort: 31),
            LoopActivity.Workout(id: "fb", name: "Football", start: start + 12 * 3600 + 20 * 60, minutes: 40, effort: 44),
        ].filter { $0.start + $0.minutes * 60 <= now }
        a.week = [
            .init(day: "mon", effort: 48, steps: 11_204, kcal: 2_310),
            .init(day: "tue", effort: 35, steps: 8_930, kcal: 2_020),
            .init(day: "wed", effort: nil, steps: nil, kcal: nil),
            .init(day: "thu", effort: 58, steps: 13_277, kcal: 1_840),
        ]
        a.zoneMinutes = [212, 96, 41, 22, 6]
        a.zoneFloors = [100, 120, 140, 160, 180]
        a.maxHR = 199
        a.kcalToday = 1_840
        return a
    }
}
#endif
