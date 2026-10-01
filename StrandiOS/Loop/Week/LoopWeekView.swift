import SwiftUI
import StrandAnalytics

/// Your week, one tap in from Home: one sentence on how effort and recovery sat together, the week's
/// standout days, and the averages against last week.
struct LoopWeekView: View {
    @Binding var today: LoopToday

    @EnvironmentObject private var repo: Repository
    @State private var week = LoopWeek.empty
    @State private var loaded = false
    @State private var titleScrolledAway = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text("Your week").font(LoopFont.title).foregroundStyle(LoopColor.text)
                } icon: {
                    Image(systemName: "calendar").font(.title3).foregroundStyle(LoopColor.text)
                }
                .padding(.top, LoopSpace.xs)
                .accessibilityAddTraits(.isHeader)

                if loaded {
                    Text(range)
                        .font(LoopFont.meta)
                        .foregroundStyle(LoopColor.muted)
                        .padding(.top, LoopSpace.xs)

                    Text(sentence)
                        .font(LoopFont.sentence)
                        .foregroundStyle(LoopColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, LoopSpace.l)

                    if week.daysWithData > 0 {
                        standouts.padding(.top, LoopSpace.l)
                        if !week.averages.isEmpty { averages.padding(.top, LoopSpace.s) }
                    }
                }
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
                ZStack {
                    LoopMark(size: 30).opacity(titleScrolledAway ? 0 : 1)
                    Text("Your week")
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
            week = await LoopWeekReader.read(repo: repo, today: today)
            withAnimation(.easeOut(duration: 0.3)) { loaded = true }
        }
    }

    // MARK: Cards

    private var standouts: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Standouts")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            standout(symbol: "moon.fill", colour: LoopColor.signal, title: "Best night",
                     day: week.bestNight?.day, value: week.bestNight.map { LoopFormat.duration($0.value * 60) })
            standout(symbol: "figure.walk", colour: LoopColor.pulse, title: "Hardest day",
                     day: week.hardestDay?.day, value: week.hardestDay.map { "Effort \(Int($0.value.rounded()))" })
            standout(symbol: "bolt.fill",
                     colour: week.bestRecovery.map { RecoveryBand(score: Int($0.value.rounded())).colour } ?? LoopColor.glow,
                     title: "Best recovery", day: week.bestRecovery?.day,
                     value: week.bestRecovery.map { r in
                         let s = Int(r.value.rounded())
                         return "\(RecoveryBand(score: s).word) \(s)"
                     })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.muted))
    }

    private func standout(symbol: String, colour: Color, title: String, day: String?, value: String?) -> some View {
        HStack(spacing: LoopSpace.s) {
            Image(systemName: symbol).font(.body).foregroundStyle(colour).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(LoopFont.rowTitle).foregroundStyle(LoopColor.text)
                if let day { Text(Self.dayName(day)).font(LoopFont.meta).foregroundStyle(LoopColor.muted) }
            }
            Spacer(minLength: LoopSpace.xs)
            Text(value ?? "No data")
                .font(LoopFont.rowValue)
                .foregroundStyle(value == nil ? LoopColor.muted : LoopColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private var averages: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text(week.isLastWeek ? "Averages, against the week before" : "Averages, against last week")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            ForEach(Array(week.averages.enumerated()), id: \.element.title) { i, a in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.title).font(LoopFont.rowTitle).foregroundStyle(LoopColor.text)
                        Spacer(minLength: LoopSpace.xs)
                        Text(a.format(a.value)).font(LoopFont.rowValue).foregroundStyle(LoopColor.text)
                    }
                    Text(changeLine(a))
                        .font(LoopFont.meta)
                        .foregroundStyle(LoopColor.muted)
                }
                .accessibilityElement(children: .combine)
                if i < week.averages.count - 1 {
                    Rectangle().fill(LoopColor.line).frame(height: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.muted))
    }

    // MARK: Words

    private var range: String {
        let from = Self.dayName(week.weekStart, format: "EEE d MMM")
        let to = Self.dayName(week.weekEnd, format: "EEE d MMM")
        return week.isLastWeek ? "Last week · \(from) to \(to)" : "This week so far · from \(from)"
    }

    /// Noop's effort-versus-recovery balance, in Loop's words.
    private var sentence: String {
        guard week.daysWithData > 0 else { return "Nothing recorded this week yet." }
        switch week.balance {
        case .overreaching: return "You pushed harder than you recovered. Ease off for a day or two."
        case .balanced: return "Effort and recovery stayed in step. A good, steady week."
        case .underloaded: return "Plenty left in the tank. Room to push if you want to."
        case .insufficient: return "A few more days and Loop can tell you how the week went."
        }
    }

    private func changeLine(_ a: LoopWeek.Average) -> String {
        guard let c = a.change else { return "Not enough of last week to compare" }
        let shown = a.format(abs(c))
        if a.format(0) == shown || abs(c) < 0.5 { return "About the same as last week" }
        // Effort isn't better or worse for being higher; the sentence up top judges the balance.
        let better = a.title != "Effort" && (c > 0) == a.higherIsBetter
        return "\(c > 0 ? "Up" : "Down") \(shown) on last week\(better ? ", nice" : "")"
    }

    /// "Tuesday" from "2026-09-29" (or another `format`).
    static func dayName(_ key: String, format: String = "EEEE") -> String {
        let parse = DateFormatter()
        parse.locale = Locale(identifier: "en_GB")
        parse.dateFormat = "yyyy-MM-dd"
        guard let d = parse.date(from: key) else { return key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = format
        return f.string(from: d)
    }
}
