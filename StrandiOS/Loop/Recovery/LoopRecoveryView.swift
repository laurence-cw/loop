import SwiftUI

/// Recovery, one tap in from Home. Headline: the orb and what today means. Then heart variability
/// and resting heart rate against your normal. Then breathing and temperature, for the curious.
struct LoopRecoveryView: View {
    @Binding var today: LoopToday

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var repo: Repository
    @State private var recovery = LoopRecovery.empty
    @State private var loaded = false
    @State private var titleScrolledAway = false


    private var tint: Color {
        today.recovery.score.map { RecoveryBand(score: $0).colour } ?? LoopColor.muted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text("Recovery").font(LoopFont.title).foregroundStyle(LoopColor.text)
                } icon: {
                    Image(systemName: "bolt.fill").font(.title3).foregroundStyle(tint)
                }
                .padding(.top, LoopSpace.xs)
                .accessibilityAddTraits(.isHeader)

                LoopOrb(recovery: today.recovery, diameter: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LoopSpace.xl)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(orbLabel)

                Text(headline)
                    .font(LoopFont.sentence)
                    .foregroundStyle(LoopColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                if case .scored(let s) = today.recovery, RecoveryBand(score: s) == .low {
                    NavigationLink { LoopBreatheView() } label: {
                        HStack(spacing: LoopSpace.s) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("About two minutes of slow breathing").font(LoopFont.body).foregroundStyle(LoopColor.text)
                                Text("It can help your body settle.").font(LoopFont.explainer).foregroundStyle(LoopColor.muted)
                            }
                            Spacer(minLength: LoopSpace.xs)
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(LoopColor.muted)
                        }
                        .padding(LoopSpace.cardPadding)
                        .background(LoopCardBackground(glow: LoopColor.glow))
                    }
                    .buttonStyle(LoopPressStyle())
                    .padding(.top, LoopSpace.m)
                }

                if loaded { measures }
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
                Text("Recovery")
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
            recovery = LoopRecoveryReader.read(repo: repo)
            withAnimation(.easeOut(duration: 0.3)) { loaded = true }
        }
    }

    /// The measures, shown only once read, so real data never flashes as "No data" first.
    private var measures: some View {
        VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: LoopSpace.s) {
                    LoopVitalCard(
                        title: "Heart variability",
                        explainer: "Higher than normal usually means your body has recovered well.",
                        vital: recovery.heartVariability,
                        glow: tint)
                    LoopVitalCard(
                        title: "Resting heart rate",
                        explainer: "Lower than normal is usually a good sign.",
                        vital: recovery.restingHeartRate,
                        glow: tint)
                }
                .padding(.top, LoopSpace.l)

                VStack(spacing: LoopSpace.s) {
                    LoopCheckRow(
                        title: "Breathing rate",
                        explainer: "Only worth noticing if it's well above your normal.",
                        state: breathingState)
                    LoopCheckRow(
                        title: "Temperature",
                        explainer: "A big jump can mean you're coming down with something.",
                        state: temperatureState,
                        divider: false)
                    NavigationLink { LoopBreatheView() } label: {
                        HStack {
                            Text("Breathe").font(LoopFont.rowTitle).foregroundStyle(LoopColor.text)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(LoopColor.muted)
                        }
                        .frame(minHeight: 44)
                    }
                    .padding(.top, LoopSpace.m)
                }
                .padding(.top, LoopSpace.xl)
        }
        .transition(.opacity)
    }

    // MARK: Words

    private var headline: String {
        switch today.recovery {
        case .scored(let s): return RecoveryBand(score: s).line
        case .carried(let s): return "\(RecoveryBand(score: s).line) That's last night's score."
        case .learning: return "Getting to know you. Your normal takes a few nights to learn."
        case .noData: return "No score yet today. Was the strap off last night?"
        }
    }

    private var orbLabel: String {
        switch today.recovery {
        case .scored(let s), .carried(let s): return "Recovery \(s) out of 100, \(RecoveryBand(score: s).word)"
        case .learning(let n, let of): return "Recovery: getting to know you, \(n) of \(of) nights"
        case .noData: return "Recovery: no score yet"
        }
    }

    private var breathingState: LoopCheckRow.State {
        guard let reading = recovery.breathing.reading else {
            return recovery.breathing.value == nil ? .noData : .learning
        }
        return reading == .high ? .off : .normal
    }

    private var temperatureState: LoopCheckRow.State {
        guard let change = recovery.temperatureChange else { return .noData }
        return abs(change) > LoopRecovery.temperatureOffBy ? .off : .normal
    }
}

// MARK: - Pieces

/// A body measure on a "normal for you" range bar: the word first, the bar, the number small beneath.
struct LoopVitalCard: View {
    let title: String
    let explainer: String
    let vital: LoopVital
    let glow: Color

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.muted)
                Text(word)
                        .font(LoopFont.rowValue)
                        .foregroundStyle(vital.reading == nil ? LoopColor.muted : LoopColor.text)
            }

            if let low = vital.normalLow, let high = vital.normalHigh {
                VStack(spacing: LoopSpace.xs) {
                    LoopRangeBar(value: vital.value, low: low, high: high)
                        .frame(height: 16)
                    HStack {
                        Text(vital.value.map { "\(Int($0.rounded()))" } ?? "No data")
                            .font(LoopFont.meta)
                            .foregroundStyle(LoopColor.text)
                        Spacer()
                        Text("Your normal \(Int(low.rounded()))–\(Int(high.rounded()))")
                            .font(LoopFont.meta)
                            .foregroundStyle(LoopColor.muted)
                    }
                }
            } else {
                Text(vital.value == nil ? "No data for last night." : "Learning your normal. A few more nights.")
                    .font(LoopFont.explainer)
                    .foregroundStyle(LoopColor.muted)
            }

            Text(explainer)
                .font(LoopFont.explainer)
                .foregroundStyle(LoopColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: glow))
        .accessibilityElement(children: .combine)
    }

    private var word: String {
        switch vital.reading {
        case .normal: return "Normal for you"
        case .high: return "Higher than normal"
        case .low: return "Lower than normal"
        case nil: return vital.value == nil ? "No data" : "Learning"
        }
    }
}

/// A track with your normal band and a dot for tonight. No numbers on the bar itself.
struct LoopRangeBar: View {
    let value: Double?
    let low: Double
    let high: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the dot is drawn: starts in the middle of your normal and eases to the value once.
    @State private var shown: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // The track shows the normal band in the middle third, with room either side.
            let span = max(high - low, 1)
            let lo = low - span, hi = high + span
            let x: (Double) -> CGFloat = { v in CGFloat((min(max(v, lo), hi) - lo) / (hi - lo)) * w }
            ZStack(alignment: .leading) {
                Capsule().fill(LoopColor.line).frame(height: 6)
                    .loopBuildIn(0, from: .leading)
                Capsule().fill(LoopColor.muted.opacity(0.45))
                    .frame(width: x(high) - x(low), height: 6)
                    .loopBuildIn(1, from: .leading, stagger: 0.2)
                    .offset(x: x(low))
                if value != nil {
                    Circle()
                        .fill(LoopColor.text)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(LoopColor.surface, lineWidth: 3))
                        .scaleEffect(shown == nil ? 0.001 : 1)
                        .opacity(shown == nil ? 0 : 1)
                        .offset(x: x(shown ?? (low + high) / 2) - 8)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
        // The dot drops in and slides to tonight once the track has drawn, the first time it's seen.
        .loopOnSeen(threshold: 0.5) { if shown == nil { settle() } }
        .onChange(of: value) { _, _ in settle() }
    }
}

extension LoopRangeBar {
    fileprivate func settle() {
        guard let value else { return }
        if reduceMotion {
            shown = value
        } else {
            withAnimation(LoopMotion.build.delay(0.45)) { shown = value }
        }
    }
}

/// "Normal / a bit off" for the deeper measures. A quiet line, not a card.
struct LoopCheckRow: View {
    enum State { case normal, off, learning, noData }

    let title: String
    let explainer: String
    let state: State
    /// A hairline below, dividing this row from the next. Off for the last row.
    var divider: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.text)
                Spacer(minLength: LoopSpace.xs)
                Text(word)
                    .font(LoopFont.rowValue)
                    .foregroundStyle(state == .normal || state == .off ? LoopColor.text : LoopColor.muted)
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

    private var word: String {
        switch state {
        case .normal: return "Normal"
        case .off: return "A bit off"
        case .learning: return "Learning"
        case .noData: return "No data"
        }
    }
}

/// Reports when the in-content screen title has scrolled away, so the bar can show a small title.
struct LoopTitleOnScroll: ViewModifier {
    @Binding var scrolledAway: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 44
            } action: { _, away in
                scrolledAway = away
            }
        } else {
            content.onAppear { scrolledAway = true }
        }
    }
}

/// iOS 26's soft scroll edge at the top, so content fades under the bar instead of meeting a hard band.
struct LoopSoftTopEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}
