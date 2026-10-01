import SwiftUI
import Combine
import StrandAnalytics

/// About two minutes of slow breathing. The orb paces the breath (grows in, shrinks out) in the
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
    @State private var orbScale: CGFloat = 0.72
    @State private var idle = false
    @State private var now = Date()

    @ScaledMetric(relativeTo: .title2) private var wordSize: CGFloat = 28
    private let diameter: CGFloat = 260
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

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
                Text(headline)
                    .font(LoopFont.sentence)
                    .foregroundStyle(LoopColor.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, LoopSpace.xl)
                    .padding(.horizontal, LoopSpace.l)

                orb
                    .frame(width: diameter * 1.18, height: diameter * 1.18)
                    .padding(.top, LoopSpace.xl)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(phaseWord ?? "Done")

                Text(remaining)
                    .font(LoopFont.meta)
                    .foregroundStyle(LoopColor.muted)
                    .padding(.top, LoopSpace.s)
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
            breatheIdle()
        }
        .onDisappear { if running { stop(finished: false) } }
    }

    // MARK: Orb (LoopOrb's own proportions, in Glow)

    private var orb: some View {
        let scale = (running ? orbScale : 0.72) * (idle && !running && !reduceMotion ? LoopMotion.breathScale : 1)
        return ZStack {
            ZStack {
            Circle()
                .fill(LoopColor.glow.opacity(LoopGlow.strong))
                .frame(width: diameter * 1.18, height: diameter * 1.18)
                .blur(radius: diameter * 0.16)
            Circle()
                .fill(LoopColor.surface)
                .overlay(Circle().fill(RadialGradient(colors: [LoopColor.glow.opacity(LoopGlow.strong), .clear],
                                                      center: .center, startRadius: 0, endRadius: diameter * 0.55)))
                .overlay(Circle().strokeBorder(LoopColor.glow.opacity(LoopGlow.strong), lineWidth: 1))
                .frame(width: diameter, height: diameter)
            }
            .scaleEffect(scale)
            // The word stays one size; only the light breathes.
            if let word = phaseWord {
                Text(word)
                    .font(LoopFont.word(size: wordSize))
                    .foregroundStyle(LoopColor.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: diameter * 0.6)
                    .id(word)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Words

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
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) {
            phase = finished ? .done : .ready
            orbScale = 0.72
        }
        announce(finished ? "Done" : "Stopped")
        breatheIdle()
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
        phaseEnds = phaseEnds.addingTimeInterval(duration)
        withAnimation(.easeInOut(duration: 0.25)) { phase = next }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: duration)) { orbScale = next == .inhale ? 1.0 : 0.72 }
        }
        announce(next == .inhale ? "In" : "Out")
        let loops = BreathProtocolPlayer.loops(for: next == .inhale ? .inhale : .exhale)
        if loops > 0 { model.buzz(loops: UInt8(clamping: loops), gate: HapticPrefs.breathing) }
    }

    /// The orb's slow idle breath when it isn't pacing (frozen under Reduce Motion).
    private func breatheIdle() {
        guard !reduceMotion else { return }
        idle = false
        withAnimation(.easeInOut(duration: LoopMotion.breathPeriod / 2).repeatForever(autoreverses: true)) {
            idle = true
        }
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
                ToolbarItem(placement: .principal) {
                    Text(title).font(LoopFont.inlineTitle).foregroundStyle(LoopColor.text)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(LoopColor.text)
    }
}
