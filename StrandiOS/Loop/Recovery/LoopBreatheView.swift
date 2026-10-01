import SwiftUI
import Combine
import StrandAnalytics

/// About two minutes of slow breathing. The orb paces the breath (grows right out on the in-breath,
/// shrinks to a seed on the out-breath) in the
/// in-between Glow colour, and the strap buzzes on each change through Noop's own gated buzz
/// (`AppModel.buzz(loops:gate:)`, one pulse in, two out, from `BreathProtocolPlayer`).
/// The pace is Noop's own, built exactly as Noop's `resonanceStages()` builds it: the wearer's locked
/// resonance pace (else 5.5 a minute), with the inhale at `BreathPacer.defaultInhaleFraction` (40%).
struct LoopBreatheView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Noop's own per-event switch for breathing buzzes (it lived in Noop's Automations screen).
    @AppStorage(HapticPrefs.breathing) private var buzzOn = true

    enum Phase { case ready, inhale, exhale, done }
    @State private var phase: Phase = .ready
    @State private var phaseEnds = Date.distantFuture
    /// The one end time the session, the countdown and the strap all stop at.
    @State private var sessionEnds: Date?
    /// Where the orb was when the current phase (or the settle back to rest) began, so every move
    /// starts from exactly where the last one left off: no jumps when the word changes.
    @State private var moveFrom: CGFloat = Self.restScale
    @State private var moveStarted = Date()
    @State private var now = Date()

    @ScaledMetric(relativeTo: .title2) private var wordSize: CGFloat = 28
    private let diameter: CGFloat = 280
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// Fully out: a small bright seed. Fully in: the whole circle.
    private static let emptyScale: CGFloat = 0.34
    private static let fullScale: CGFloat = 1.0
    /// At rest the orb sits half-full and drifts very slightly.
    private static let restScale: CGFloat = 0.56
    private static let restDrift: CGFloat = 0.025
    /// How long the orb takes to settle back to rest after Stop or Done.
    private static let settle: TimeInterval = 1.4

    // MARK: Noop's pace

    private var cycle: TimeInterval { 60.0 / (BiofeedbackPrefs.lockedPace ?? ResonanceEngine.fallbackBpm) }
    private var inhale: TimeInterval { cycle * BreathPacer.defaultInhaleFraction }
    private var exhale: TimeInterval { max(cycle - inhale, 0.5) }
    /// A whole number of breaths, about two minutes.
    private var breaths: Int { max(1, Int((120 / cycle).rounded())) }

    private var running: Bool { phase == .inhale || phase == .exhale }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Every headline is laid out (hidden) so the orb never shifts when the words change.
                ZStack {
                    ForEach(Self.allHeadlines, id: \.self) { Text($0).hidden() }
                    Text(headline)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: phase)
                }
                .font(LoopFont.sentence)
                .foregroundStyle(LoopColor.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, LoopSpace.xl)
                .padding(.horizontal, LoopSpace.l)

                TimelineView(.animation(paused: reduceMotion)) { context in
                    orb(scale: scale(at: context.date))
                }
                .frame(width: diameter * 1.25, height: diameter * 1.25)
                .padding(.top, LoopSpace.l)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(phaseWord ?? "Done")

                Text(remaining)
                    .font(LoopFont.meta)
                    .foregroundStyle(LoopColor.muted)
                    .padding(.top, LoopSpace.xs)
                    .opacity(running ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: LoopSpace.s) {
                Toggle(isOn: $buzzOn) {
                    Text(live.bonded ? "Strap buzz" : "Strap buzz (connect your strap)")
                        .font(LoopFont.body)
                        .foregroundStyle(live.bonded ? LoopColor.text : LoopColor.muted)
                }
                .tint(LoopColor.charged)
                .padding(.horizontal, LoopSpace.cardPadding)
                .frame(minHeight: 56)
                .background(RoundedRectangle(cornerRadius: LoopShape.cardRadius, style: .continuous)
                    .fill(LoopColor.surface))

                LoopPrimaryButton(title: running ? "Stop" : (phase == .done ? "Again" : "Start")) {
                    running ? stop(finished: false) : start()
                }
            }
            .padding(.horizontal, LoopSpace.edge)
            .padding(.top, LoopSpace.xs)
            .padding(.bottom, LoopSpace.m)
        }
        .modifier(LoopSoftBottomEdge())
        .background(LoopColor.night.ignoresSafeArea())
        .loopListTitle("Breathe")
        .onReceive(tick) { t in now = t; advance(t) }
        .onAppear {
            // Noop treats a missing breathing-buzz setting as off; Loop's switch starts on, so write it
            // once to make the switch and the strap agree.
            if UserDefaults.standard.object(forKey: HapticPrefs.breathing) == nil { buzzOn = true }
            #if DEBUG
            // DEBUG-only: `--loop-breathe-start` starts a session on open, for screenshots.
            if CommandLine.arguments.contains("--loop-breathe-start") { start() }
            #endif
        }
        .onDisappear { if running { stop(finished: false) } }
    }

    // MARK: Orb motion

    /// Sine ease: slow off the mark, slow into the turn, the way a breath actually moves.
    private static func ease(_ p: Double) -> CGFloat {
        CGFloat(0.5 - 0.5 * cos(.pi * min(max(p, 0), 1)))
    }

    /// The orb's size at a moment, worked out from the clock rather than animated, so the pace is
    /// exact and a phase change can never jolt it.
    private func scale(at t: Date) -> CGFloat {
        if reduceMotion { return running ? 0.8 : Self.restScale }
        if running {
            let target = phase == .inhale ? Self.fullScale : Self.emptyScale
            let e = Self.ease(t.timeIntervalSince(moveStarted) / max(phaseEnds.timeIntervalSince(moveStarted), 0.1))
            return moveFrom + (target - moveFrom) * e
        }
        let drift = Self.restDrift * CGFloat(sin(2 * .pi * t.timeIntervalSinceReferenceDate / LoopMotion.breathPeriod))
        let rest = Self.restScale + drift
        let e = Self.ease(t.timeIntervalSince(moveStarted) / Self.settle)
        return moveFrom + (rest - moveFrom) * e
    }

    /// How full the breath is, 0 (all out) to 1 (all in). The light follows it.
    private func fullness(_ scale: CGFloat) -> Double {
        Double((scale - Self.emptyScale) / (Self.fullScale - Self.emptyScale))
    }

    // MARK: Orb (LoopOrb's own proportions, in Glow)

    private func orb(scale: CGFloat) -> some View {
        let f = fullness(scale)
        return ZStack {
            // Where a full breath reaches: a faint guide ring, always there.
            Circle()
                .strokeBorder(LoopColor.glow.opacity(0.22), lineWidth: 1)
                .frame(width: diameter, height: diameter)

            // The light behind: brighter and wider the fuller the breath.
            Circle()
                .fill(LoopColor.glow.opacity(0.12 + 0.3 * f))
                .frame(width: diameter * 1.15, height: diameter * 1.15)
                .blur(radius: diameter * 0.14)
                .scaleEffect(scale)

            // Two ripples that open out as the breath fills and fold back in as it empties.
            ForEach(1...2, id: \.self) { i in
                Circle()
                    .strokeBorder(LoopColor.glow.opacity((0.35 / Double(i)) * f), lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(scale * (1 + 0.07 * CGFloat(i) * CGFloat(f)))
            }

            // The orb itself.
            Circle()
                .fill(LoopColor.surface)
                .overlay(Circle().fill(RadialGradient(
                    colors: [LoopColor.glow.opacity(0.55 - 0.25 * f), LoopColor.glow.opacity(0.08)],
                    center: .center, startRadius: 0, endRadius: diameter * 0.5)))
                .overlay(Circle().strokeBorder(LoopColor.glow.opacity(0.5), lineWidth: 1))
                .frame(width: diameter, height: diameter)
                .scaleEffect(scale)

            // The word stays one size and in one place; only the light breathes.
            if let word = phaseWord {
                Text(word)
                    .font(LoopFont.word(size: wordSize))
                    .foregroundStyle(LoopColor.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: diameter * 0.5)
                    // The old word is gone before the new one arrives, so the two never overlap.
                    .id(word)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.3).delay(0.2)),
                        removal: .opacity.animation(.easeOut(duration: 0.2))))
            }
        }
        .animation(.default, value: phaseWord)
    }

    // MARK: Words

    private static let allHeadlines = [
        "Slow breathing helps your body settle. About two minutes.",
        "Breathe with the words.",
        "Breathe in as it grows, out as it shrinks.",
        "Done. Nice and calm.",
    ]

    private var headline: String {
        switch phase {
        case .ready: return "Slow breathing helps your body settle. About two minutes."
        case .inhale, .exhale: return reduceMotion ? "Breathe with the words." : "Breathe in as it grows, out as it shrinks."
        case .done: return "Done. Nice and calm."
        }
    }

    /// The word in the orb. None when the headline already says it (Done).
    private var phaseWord: String? {
        switch phase {
        case .ready: return "Ready"
        case .inhale: return "In"
        case .exhale: return "Out"
        case .done: return nil
        }
    }

    private var remaining: String {
        guard let sessionEnds else { return " " }
        let left = max(Int(sessionEnds.timeIntervalSince(now).rounded(.up)), 0)
        return String(format: "%d:%02d left", left / 60, left % 60)
    }

    // MARK: Pacing

    private func start() {
        let t = Date()
        sessionEnds = t.addingTimeInterval(Double(breaths) * cycle)
        ScreenIdle.keepAwake(true)
        phaseEnds = t
        enter(.inhale)
    }

    private func stop(finished: Bool) {
        let wasRunning = running
        // Noop's own stop: halt any pattern the strap is mid-way through whenever a session was
        // running, whatever the switch says now (#769; a no-op when not bonded).
        if wasRunning { model.stopHaptics() }
        ScreenIdle.keepAwake(false)
        phaseEnds = .distantFuture
        sessionEnds = nil
        let t = Date()
        moveFrom = scale(at: t)
        moveStarted = t
        phase = finished ? .done : .ready
        announce(finished ? "Done" : "Stopped")
    }

    private func advance(_ t: Date) {
        guard running, t >= phaseEnds else { return }
        // The session ends exactly when the countdown reaches zero: after the last exhale.
        if let sessionEnds, t >= sessionEnds.addingTimeInterval(-0.05) {
            stop(finished: true)
            return
        }
        // After a pause (the app was in the background), carry on from now rather than racing through
        // missed breaths, which would fire the strap buzz in quick bursts.
        if t.timeIntervalSince(phaseEnds) > 1 { phaseEnds = t }
        enter(phase == .inhale ? .exhale : .inhale)
    }

    /// Each phase starts at the previous one's deadline, not at the tick that noticed it, so the
    /// breaths keep exact time with the countdown's one end time.
    private func enter(_ next: Phase) {
        let duration = next == .inhale ? inhale : exhale
        // The move starts from wherever the orb is now and lands on the phase's deadline.
        let t = Date()
        moveFrom = scale(at: t)
        moveStarted = t
        phaseEnds = phaseEnds.addingTimeInterval(duration)
        phase = next
        announce(next == .inhale ? "In" : "Out")
        let loops = BreathProtocolPlayer.loops(for: next == .inhale ? .inhale : .exhale)
        if loops > 0 { model.buzz(loops: UInt8(clamping: loops), gate: HapticPrefs.breathing) }
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

extension View {
    /// An inline Expanded title in the bar, the way Loop's other pushed screens show theirs.
    func loopListTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { LoopBarTitle(title: title) }
                LoopGaugesToolbarItem()
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(LoopColor.text)
    }
}
