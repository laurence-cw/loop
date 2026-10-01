import SwiftUI
import Combine
import CoreBluetooth
import StrandAnalytics

/// Loop's first run: four screens, no more. Welcome, Bluetooth, Pair your strap, About you.
/// Pairing goes through Noop's own call (`AppModel.scan(model:)`), never `disconnect()`
/// and Noop's own signals (`LiveState.connected` / `.bonded`), the way Noop's own setup does.
/// Loop changes nothing about how it connects.
struct LoopSetupView: View {
    let onFinished: () -> Void

    enum Step: Int, CaseIterable { case welcome, bluetooth, pair, aboutYou }
    @State private var step: Step = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LoopStepDots(count: Step.allCases.count, current: step.rawValue)
                if step != .welcome {
                    HStack {
                        Button { back() } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.medium))
                                .foregroundStyle(LoopColor.text)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.leading, LoopSpace.xs)
                }
            }
            .frame(height: 44)
            .padding(.top, LoopSpace.xs)

            Group {
                switch step {
                case .welcome: LoopWelcomeStep { go(.bluetooth) }
                case .bluetooth: LoopBluetoothStep { go(.pair) }
                case .pair: LoopPairStep { go(.aboutYou) }
                case .aboutYou: LoopAboutYouStep(onDone: onFinished)
                }
            }
            .transition(.opacity)
            .id(step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LoopColor.night.ignoresSafeArea())
        .preferredColorScheme(.dark)
        // The system's edge-swipe back, kept alive for a flow that swaps steps in place.
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.startLocation.x < 24, v.translation.width > 80 { back() }
        })
    }

    private func go(_ next: Step) {
        if reduceMotion { step = next } else { withAnimation(.easeInOut(duration: 0.35)) { step = next } }
    }

    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        go(prev)
    }
}

// MARK: - Shell

/// One setup screen: a title, one plain line, the content (scrolls at large text sizes), and the
/// button pinned at the bottom.
private struct LoopStepShell<Content: View>: View {
    let title: String
    let line: String
    /// Nil when the screen's action is in its content (tapping a strap).
    let button: String?
    var buttonEnabled = true
    let action: () -> Void
    var secondary: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(LoopFont.title)
                    .foregroundStyle(LoopColor.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, LoopSpace.l)
                    .accessibilityAddTraits(.isHeader)
                Text(line)
                    .font(LoopFont.sentence)
                    .foregroundStyle(LoopColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, LoopSpace.s)
                content
                    .frame(maxWidth: .infinity)
                    .padding(.top, LoopSpace.xl)
            }
            .padding(.horizontal, LoopSpace.edge)
            .padding(.bottom, LoopSpace.m)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: LoopSpace.xs) {
                if let button {
                    LoopPrimaryButton(title: button, enabled: buttonEnabled, action: action)
                }
                if let secondary { secondary }
            }
            .padding(.horizontal, LoopSpace.edge)
            .padding(.top, LoopSpace.xs)
            .padding(.bottom, LoopSpace.s)
        }
        .modifier(LoopSoftBottomEdge())
    }
}

struct LoopPrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? LoopColor.night : LoopColor.muted)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(enabled ? LoopColor.text : LoopColor.surface))
        }
        .buttonStyle(LoopPressStyle())
        .disabled(!enabled)
    }
}

/// Four dots: done in Muted, the current one wide in Text, the rest in Line. Glow is left to the orb.
struct LoopStepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: LoopSpace.xs) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? LoopColor.text : (i < current ? LoopColor.muted : LoopColor.line))
                    .frame(width: i == current ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

// MARK: - 1 Welcome

private struct LoopWelcomeStep: View {
    let next: () -> Void

    var body: some View {
        LoopStepShell(title: "Loop",
                      line: "Sleep fills the tank. Activity spends it. Recovery shows what's left.",
                      button: "Get started", action: next) {
            LoopWelcomeOrb()
                .frame(height: 260)
                .accessibilityHidden(true)
        }
    }
}

/// The orb in its in-between Glow, with no number yet: nothing has been measured.
private struct LoopWelcomeOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle().fill(LoopColor.glow.opacity(LoopGlow.strong))
                .frame(width: 210, height: 210).blur(radius: 30)
            Circle().fill(LoopColor.surface)
                .overlay(Circle().fill(RadialGradient(colors: [LoopColor.glow.opacity(LoopGlow.strong), .clear],
                                                      center: .center, startRadius: 0, endRadius: 100)))
                .overlay(Circle().strokeBorder(LoopColor.glow.opacity(LoopGlow.strong), lineWidth: 1))
                .frame(width: 180, height: 180)
        }
        .scaleEffect(breathing && !reduceMotion ? LoopMotion.breathScale : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: LoopMotion.breathPeriod / 2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

// MARK: - 2 Bluetooth

private struct LoopBluetoothStep: View {
    let next: () -> Void
    @State private var auth = CBManager.authorization
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        LoopStepShell(title: "Bluetooth",
                      line: "Loop talks to your strap over Bluetooth. Nothing leaves your phone.",
                      button: buttonTitle, action: action) {
            VStack(spacing: LoopSpace.m) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(LoopColor.text)
                Text(statusLine)
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, LoopSpace.xl)
        }
        .onReceive(timer) { _ in auth = CBManager.authorization }
    }

    private var statusLine: String {
        switch auth {
        case .allowedAlways: return "Bluetooth is allowed. You're ready."
        case .denied, .restricted: return "Bluetooth is turned off for Loop. Turn it on in the phone's Settings."
        default: return "When your phone asks, tap Allow."
        }
    }

    private var buttonTitle: String {
        switch auth {
        case .denied, .restricted: return "Open Settings"
        default: return "Continue"
        }
    }

    private func action() {
        switch auth {
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        default:
            next()
        }
    }
}

// MARK: - 3 Pair your strap

private struct LoopPairStep: View {
    let next: () -> Void
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @AppStorage("selectedWhoopModel") private var selectedModelRaw = ""
    @AppStorage(LoopPrefs.pairLaterKey) private var pairLater = false
    @State private var picked: WhoopModel?
    @State private var searching = false
    @State private var showHelp = false
    /// Bumped on every new search, so a timer from an earlier attempt can never fire.
    @State private var attempt = 0

    var body: some View {
        LoopStepShell(title: title,
                      line: line,
                      button: picked == nil ? nil : buttonTitle,
                      buttonEnabled: buttonEnabled,
                      action: action,
                      secondary: live.bonded ? nil : AnyView(
                        Button("Pair later") { pairLater = true; next() }
                            .font(LoopFont.body)
                            .foregroundStyle(LoopColor.muted)
                            .frame(minHeight: 44)
                      )) {
            pairContent
        }
        .onChange(of: live.bonded) { _, bonded in
            if bonded { searching = false; showHelp = false; pairLater = false }
        }
        .onAppear {
            // Coming back after pairing: show the paired strap and Continue, not the choice again.
            if live.bonded, picked == nil { picked = WhoopModel(rawValue: selectedModelRaw) }
        }
        .onDisappear {
            // Leaving mid-search (Back, or Pair later) leaves Noop's connect attempt running, as Noop's own
            // setup does: the strap pairs whenever it turns up. Calling `disconnect()` here would latch
            // Noop's intentional-disconnect flag, which switches off every automatic reconnect until the
            // app restarts. Only this screen's own timer is retired.
            attempt += 1
            searching = false
        }
    }

    @ViewBuilder
    private var pairContent: some View {
        if let chosen = picked {
            VStack(alignment: .leading, spacing: LoopSpace.m) {
                LoopStrapPicture(model: chosen)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                if !live.bonded {
                    VStack(alignment: .leading, spacing: LoopSpace.s) {
                        ForEach(Array(steps(chosen).enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .firstTextBaseline, spacing: LoopSpace.s) {
                                Text("\(i + 1)").font(LoopFont.meta).foregroundStyle(LoopColor.muted)
                                    .frame(width: 16)
                                Text(s).font(LoopFont.body).foregroundStyle(LoopColor.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if showHelp {
                        Text("Can't find it yet. Check it's charged, on your wrist and close by, then try again.")
                            .font(LoopFont.explainer)
                            .foregroundStyle(LoopColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Choose a different strap") { switchStrap() }
                        .font(LoopFont.explainer)
                        .foregroundStyle(LoopColor.muted)
                        .frame(minHeight: 44)
                }
            }
        } else {
            HStack(spacing: LoopSpace.s) {
                ForEach(WhoopModel.allCases) { m in
                    Button { picked = m; selectedModelRaw = m.rawValue } label: {
                        VStack(spacing: LoopSpace.s) {
                            LoopStrapPicture(model: m)
                                .frame(height: 110)
                            Text(short(m)).font(LoopFont.rowValue).foregroundStyle(LoopColor.text)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(RoundedRectangle(cornerRadius: LoopShape.cardRadius, style: .continuous)
                            .fill(LoopColor.surface))
                    }
                    .buttonStyle(LoopPressStyle())
                    .accessibilityLabel("WHOOP \(short(m))")
                }
            }
        }
    }

    private var title: String {
        guard let chosen = picked else { return "Pair your strap" }
        return live.bonded ? "Connected" : "Pair your \(short(chosen))"
    }

    /// One readout per state: choosing, ready, looking, connecting, connected.
    private var line: String {
        guard picked != nil else { return "Which strap do you have? Tap it." }
        if live.bonded { return "Your strap is ready." }
        if live.connected { return "Found it. Connecting…" }
        return searching ? "Looking for your strap…" : "Do these, then tap Find my strap."
    }

    private func steps(_ m: WhoopModel) -> [String] {
        switch m {
        case .whoop4:
            return ["Put the strap on your wrist.", "Keep your phone close by."]
        case .whoop5mg:
            return ["Close the official WHOOP app.",
                    "Tap the band until its lights flash blue.",
                    "Keep your phone close by."]
        }
    }

    private var buttonTitle: String {
        if live.bonded { return "Continue" }
        if live.connected { return "Connecting…" }
        return searching ? "Looking…" : "Find my strap"
    }

    private var buttonEnabled: Bool { live.bonded || (!searching && !live.connected) }

    private func action() {
        if live.bonded { next(); return }
        guard let picked else { return }
        attempt += 1
        let mine = attempt
        searching = true
        showHelp = false
        model.scan(model: picked)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            // Only this attempt's timer counts, and never while a strap is mid-connect.
            guard mine == attempt, !live.bonded, !live.connected else { return }
            searching = false
            showHelp = true
        }
    }

    /// Back to the choice. No `disconnect()`: the next "Find my strap" goes through Noop's `connect`,
    /// which itself releases a half-made link to the other strap family, and leaving one running in the
    /// meantime keeps auto-reconnect alive (`disconnect()` would switch it off until relaunch).
    private func switchStrap() {
        attempt += 1
        searching = false
        showHelp = false
        picked = nil
    }

    private func short(_ m: WhoopModel) -> String { m == .whoop4 ? "4.0" : "5.0" }
}

/// A plain drawn strap: a band with a sensor pod. Generic on purpose, never WHOOP's own artwork.
/// The 4.0 pod is drawn deeper and squarer with a clasp line; the 5.0 pod wider and slimmer.
struct LoopStrapPicture: View {
    let model: WhoopModel

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.8, 160), h = geo.size.height
            ZStack {
                Capsule()
                    .stroke(LoopColor.line, lineWidth: h * 0.16)
                    .frame(width: w, height: h * 0.62)
                if model == .whoop4 {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LoopColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(LoopColor.text, lineWidth: 1.5))
                        .overlay(Rectangle().fill(LoopColor.muted).frame(width: 1.5, height: h * 0.2))
                        .frame(width: w * 0.36, height: h * 0.46)
                } else {
                    Capsule()
                        .fill(LoopColor.surface)
                        .overlay(Capsule().stroke(LoopColor.text, lineWidth: 1.5))
                        .frame(width: w * 0.56, height: h * 0.3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 4 About you

private struct LoopAboutYouStep: View {
    let onDone: () -> Void
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var behavior: BehaviorStore
    @EnvironmentObject private var profile: ProfileStore
    @AppStorage(LoopPrefs.firstNameKey) private var savedName = ""
    @State private var firstName = ""
    /// Asked directly, the way the brand book says. Nil until he picks one.
    @State private var age: Int?
    @State private var wake = WindDownNudge.wakeMinutes
    @FocusState private var nameFocused: Bool

    /// Noop's own date-of-birth range starts at 13. Teens first; adults (a parent testing) further down.
    private let ages = Array(13...70)

    var body: some View {
        LoopStepShell(title: "About you",
                      line: "So Loop can say hello, and work out your effort and sleep.",
                      button: "Done", buttonEnabled: !trimmedName.isEmpty && age != nil, action: finish) {
            VStack(spacing: 0) {
                row {
                    Text("First name")
                    TextField("Your name", text: $firstName)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                divider
                row {
                    Text("Age")
                    Spacer()
                    Menu {
                        ForEach(ages, id: \.self) { a in Button("\(a)") { age = a } }
                    } label: {
                        Text(age.map { "\($0)" } ?? "Choose")
                            .foregroundStyle(age == nil ? LoopColor.muted : LoopColor.text)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(LoopColor.line))
                    }
                }
                divider
                row {
                    DatePicker("School-day wake-up", selection: Binding(
                        get: { LoopWake.date(wake) }, set: { wake = LoopWake.minutes($0) }
                    ), displayedComponents: .hourAndMinute)
                }
            }
            .font(LoopFont.body)
            .foregroundStyle(LoopColor.text)
            .background(RoundedRectangle(cornerRadius: LoopShape.cardRadius, style: .continuous)
                .fill(LoopColor.surface))
            .environment(\.colorScheme, .dark)
            .tint(LoopColor.charged)
        }
        .onAppear {
            firstName = savedName
            nameFocused = trimmedName.isEmpty
        }
    }

    private var trimmedName: String { firstName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func row<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack { c() }.padding(.horizontal, LoopSpace.cardPadding).frame(minHeight: 56)
    }

    private var divider: some View {
        Rectangle().fill(LoopColor.line).frame(height: 1).padding(.leading, LoopSpace.cardPadding)
    }

    private func finish() {
        guard let age else { return }
        savedName = trimmedName
        // Age goes into Noop's own profile through Noop's own conversion (effort uses it).
        profile.dateOfBirth = ProfileStore.dateOfBirth(forAge: age)
        // School-day wake time sets Noop's usual wake and base alarm; weekends start the same and can
        // be changed in Settings. The buzz itself stays off until he turns it on.
        LoopWake.setSchoolDays(wake, keepingWeekend: wake, behavior: behavior)
        model.applySmartAlarm()
        onDone()
    }
}

/// iOS 26's soft scroll edge at the bottom, so content fades under the pinned buttons instead of
/// being cut off mid-line.
struct LoopSoftBottomEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}
