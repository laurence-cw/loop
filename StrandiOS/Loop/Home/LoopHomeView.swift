import SwiftUI
import UIKit

/// Loop's Home. Above the fold: the status pill, the loop ring and one sentence. Nothing else.
/// Below it: one quiet row per section.
struct LoopHomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var live: LiveState

    @AppStorage(LoopPrefs.firstNameKey) private var firstName = ""
    @State private var today = LoopToday.empty
    @State private var showFindStrap = false
    @State private var openRecovery = false
    @State private var openSleep = false
    @State private var openActivity = false
    @State private var openSettings = false
    private static let rowsAnchor = "loop.home.rows"

    private var status: LoopStatus {
        LoopStatus.resolve(live: live, hasStrap: !(model.deviceRegistry?.devices.isEmpty ?? true))
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        hero
                            // At least one screen tall, so the rows always start below the fold; taller
                            // when large text needs the room, rather than overflowing into the rows.
                            .frame(minHeight: viewport.size.height)
                        rows
                            .padding(.top, LoopSpace.xl)
                            .padding(.horizontal, LoopSpace.edge)
                            .padding(.bottom, LoopSpace.xl)
                            .id(Self.rowsAnchor)
                    }
                }
                #if DEBUG
                // DEBUG-only: `--loop-scroll-rows` opens Home scrolled to the rows, for screenshots.
                .onAppear {
                    if CommandLine.arguments.contains("--loop-scroll-rows") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            proxy.scrollTo(Self.rowsAnchor, anchor: .bottom)
                        }
                    }
                }
                #endif
            }
        }
        .scrollIndicators(.hidden)
        .background(LoopColor.night.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task(id: repo.refreshSeq) {
            today = await LoopTodayReader.read(repo: repo, profile: profile)
            #if DEBUG
            if let preview = LoopPreviewState.requested { today = preview.apply(to: today) }
            if CommandLine.arguments.contains("--loop-open-recovery") { openRecovery = true }
            if CommandLine.arguments.contains("--loop-open-sleep") { openSleep = true }
            if CommandLine.arguments.contains("--loop-open-activity") { openActivity = true }
            if CommandLine.arguments.contains("--loop-open-settings") { openSettings = true }
            #endif
        }
        .refreshable { model.ble.syncNow() }
        .navigationDestination(isPresented: $openRecovery) { LoopRecoveryView(today: $today) }
        .navigationDestination(isPresented: $openSleep) { LoopSleepView(today: $today) }
        .navigationDestination(isPresented: $openActivity) { LoopActivityView(today: $today) }
        .navigationDestination(isPresented: $openSettings) { LoopSettingsView() }
        .sheet(isPresented: $showFindStrap) {
            LoopFindStrapSheet(status: status)
                .presentationDetents([.medium])
        }
    }

    // MARK: Above the fold

    /// Pill at the top; the ring, its two values and the sentence sit together as one group, centred
    /// in what's left, with fixed gaps inside the group.
    private var hero: some View {
        VStack(spacing: 0) {
            LoopStatusPill(status: status, battery: live.batteryPct) { showFindStrap = true }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    Button { openSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(LoopColor.muted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                    .padding(.trailing, LoopSpace.xs)
                }
                .padding(.top, LoopSpace.xs)

            if status == .bluetoothOff {
                LoopBluetoothCard()
                    .padding(.horizontal, LoopSpace.edge)
                    .padding(.top, LoopSpace.s)
            }

            Spacer(minLength: LoopSpace.xl)

            VStack(spacing: 0) {
                Button { openRecovery = true } label: {
                    LoopRing(today: today, sleepFraction: sleepFraction, effortFraction: effortFraction)
                        .frame(maxWidth: 320)
                        .contentShape(Circle())
                }
                .buttonStyle(LoopPressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ringAccessibilityLabel)
                .accessibilityHint("Opens Recovery")

                arcFeet
                    .frame(maxWidth: 320)
                    .padding(.top, LoopSpace.s)

                Text(sentence)
                    .font(LoopFont.sentence)
                    .foregroundStyle(LoopColor.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, LoopSpace.xl)
            }
            .padding(.horizontal, LoopSpace.l)

            Spacer(minLength: LoopSpace.xl)
        }
    }

    /// Each arc's value at its outer foot, marked by its section's symbol.
    /// Side by side at each foot when they fit; stacked (left value above right) at large text sizes.
    private var arcFeet: some View {
        let sleep = footValue(symbol: "moon.fill", colour: LoopColor.signal,
                              text: today.sleepMin.map { LoopFormat.duration($0 * 60) })
        let effort = footValue(symbol: "figure.walk", colour: LoopColor.pulse,
                               text: today.effort.map { "\(Int($0.rounded()))" }, unit: "/100")
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: LoopSpace.l) {
                sleep.fixedSize()
                Spacer(minLength: LoopSpace.l)
                effort.fixedSize()
            }
            VStack(spacing: LoopSpace.xs) {
                sleep.frame(maxWidth: .infinity, alignment: .leading)
                effort.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityHidden(true)
    }

    private func footValue(symbol: String, colour: Color, text: String?, unit: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(colour)
            if let text {
                (Text(text).foregroundStyle(LoopColor.text)
                 + Text(unit ?? "").font(.footnote.weight(.medium)).foregroundStyle(LoopColor.muted))
                    .font(LoopFont.rowValue)
            } else {
                Text("No data")
                    .font(LoopFont.rowValue)
                    .foregroundStyle(LoopColor.muted)
            }
        }
    }

    // MARK: Below the fold

    private var rows: some View {
        VStack(spacing: LoopSpace.s) {
            Button { openRecovery = true } label: {
                LoopSectionRow(symbol: "bolt.fill", title: "Recovery", colour: recoveryColour,
                               word: recoveryWord, value: today.recovery.score.map { "\($0)" }, opens: true)
            }
            .buttonStyle(LoopPressStyle())
            Button { openSleep = true } label: {
                LoopSectionRow(symbol: "moon.fill", title: "Sleep", colour: LoopColor.signal,
                               word: sleepWord, value: today.sleepMin.map { LoopFormat.duration($0 * 60) },
                               opens: true)
            }
            .buttonStyle(LoopPressStyle())
            Button { openActivity = true } label: {
                LoopSectionRow(symbol: "figure.walk", title: "Activity", colour: LoopColor.pulse,
                               word: effortWord, value: today.effort.map { "\(Int($0.rounded()))" },
                               detail: today.steps.map { "\(LoopFormat.steps($0)) steps" }, opens: true)
            }
            .buttonStyle(LoopPressStyle())
        }
    }

    // MARK: Words

    private var sentence: String {
        let hello = LoopFormat.greeting(name: firstName)
        switch today.recovery {
        case .scored(let s), .carried(let s):
            return "\(hello) \(RecoveryBand(score: s).line)"
        case .learning(let nights, let of):
            let left = max(of - nights, 1)
            return "\(hello) Getting to know you. Give it \(left) more \(left == 1 ? "night" : "nights")."
        case .noData:
            return "\(hello) No score yet today. Was the strap off last night?"
        }
    }

    private var recoveryColour: Color {
        today.recovery.score.map { RecoveryBand(score: $0).colour } ?? LoopColor.muted
    }

    private var recoveryWord: String? {
        today.recovery.score.map { RecoveryBand(score: $0).word }
    }

    private var sleepFraction: Double? {
        today.sleepMin.map { $0 / max(today.sleepNeedMin, 1) }
    }

    /// The word comes from Noop's own sleep score, not from Loop's arithmetic.
    private var sleepWord: String? {
        today.sleepScore.map { ScoreWord.word(for: $0) }
    }

    private var effortFraction: Double? {
        today.effort.map { $0 / 100 }
    }

    private var effortWord: String? {
        today.effort.map { ScoreWord.word(for: Int($0.rounded())) }
    }

    private var ringAccessibilityLabel: String {
        var parts: [String] = []
        switch today.recovery {
        case .scored(let s), .carried(let s):
            parts.append("Recovery \(s) out of 100, \(RecoveryBand(score: s).word)")
        case .learning(let n, let of):
            parts.append("Recovery: getting to know you, \(n) of \(of) nights")
        case .noData:
            parts.append("Recovery: no score yet")
        }
        if let m = today.sleepMin {
            parts.append("Sleep \(LoopFormat.duration(m * 60)) of \(LoopFormat.duration(today.sleepNeedMin * 60)) needed")
        } else {
            parts.append("Sleep: no data")
        }
        if let e = today.effort { parts.append("Effort \(Int(e.rounded())) out of 100") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Pieces

/// One section row below the fold. A Surface card with its section's colour glowing from the left edge.
/// The word and the number share one baseline: "Steady 58".
struct LoopSectionRow: View {
    let symbol: String
    let title: String
    let colour: Color
    let word: String?
    let value: String?
    /// An optional second fact under the title, e.g. steps under Activity.
    var detail: String? = nil
    /// Shows a chevron when the row opens its section.
    var opens: Bool = false

    var body: some View {
        HStack(spacing: LoopSpace.s) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(colour)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.text)
                if let detail {
                    Text(detail)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(LoopColor.muted)
                }
            }
            Spacer(minLength: LoopSpace.xs)
            HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
                if let value {
                    if let word {
                        Text(word)
                            .font(LoopFont.rowValue)
                            .foregroundStyle(colour)
                    }
                    Text(value)
                        .font(LoopFont.rowValue)
                        .foregroundStyle(LoopColor.text)
                } else {
                    Text("No data")
                        .font(LoopFont.rowValue)
                        .foregroundStyle(LoopColor.muted)
                }
            }
            if opens {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(LoopColor.muted)
            }
        }
        .padding(LoopSpace.cardPadding)
        .frame(minHeight: 72)
        .background(LoopCardBackground(glow: colour))
        .accessibilityElement(children: .combine)
    }
}

/// Surface card with one colour glowing softly from its leading edge. No border, never nested.
struct LoopCardBackground: View {
    let glow: Color

    var body: some View {
        RoundedRectangle(cornerRadius: LoopShape.cardRadius, style: .continuous)
            .fill(LoopColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: LoopShape.cardRadius, style: .continuous)
                    .fill(
                        RadialGradient(colors: [glow.opacity(LoopGlow.soft), .clear],
                                       center: .leading, startRadius: 0, endRadius: 140)
                    )
            )
    }
}

/// The small status pill at the top of Home. Tappable only when something needs fixing.
/// It never borrows Recovery's colours: Recovery is the only thing in Loop that changes colour.
struct LoopStatusPill: View {
    let status: LoopStatus
    let battery: Double?
    let onHelp: () -> Void

    var body: some View {
        Button(action: onHelp) {
            HStack(spacing: LoopSpace.xs) {
                icon
                Text(status.text)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(status.needsHelp ? LoopColor.text : LoopColor.muted)
                if let b = battery, b < 20, !status.needsHelp {
                    Image(systemName: "battery.25percent")
                        .font(.footnote)
                        .foregroundStyle(LoopColor.text)
                    Text("\(Int(b.rounded()))%")
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .foregroundStyle(LoopColor.text)
                }
                if status.needsHelp {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(LoopColor.muted)
                }
            }
            .padding(.horizontal, LoopSpace.s)
            .frame(minHeight: 44)
            .background(Capsule().fill(LoopColor.surface))
        }
        .buttonStyle(.plain)
        .disabled(!status.needsHelp)
        .animation(LoopMotion.colourFade, value: status)
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .syncing:
            ProgressView().controlSize(.mini).tint(LoopColor.muted)
        case .synced:
            Image(systemName: "checkmark.circle").font(.footnote).foregroundStyle(LoopColor.muted)
        case .cantFind, .bluetoothOff, .noStrap:
            Image(systemName: "exclamationmark.circle").font(.footnote).foregroundStyle(LoopColor.text)
        }
    }
}

/// Bluetooth switched off: one card, one button.
struct LoopBluetoothCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Bluetooth is off, so Loop can't reach your strap.")
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LoopColor.night)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(LoopColor.text))
            }
            .buttonStyle(.plain)
        }
        .padding(LoopSpace.cardPadding)
        .background(RoundedRectangle(cornerRadius: LoopShape.cardRadius, style: .continuous).fill(LoopColor.surface))
    }
}

/// "Find my strap": one button plus three quick checks.
struct LoopFindStrapSheet: View {
    let status: LoopStatus
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.m) {
            VStack(alignment: .leading, spacing: LoopSpace.xs) {
                Text("Can't find your strap")
                    .font(LoopFont.title)
                    .foregroundStyle(LoopColor.text)
                if case .cantFind(let last?) = status {
                    Text("Last synced \(LoopFormat.clock(last)).")
                        .font(LoopFont.body)
                        .foregroundStyle(LoopColor.muted)
                }
            }
            VStack(alignment: .leading, spacing: LoopSpace.s) {
                check("battery.100percent", "Is it charged?")
                check("antenna.radiowaves.left.and.right", "Is it nearby, on your wrist?")
                check("dot.radiowaves.right", "Is Bluetooth on?")
            }
            Spacer(minLength: 0)
            Button {
                model.scan()
                dismiss()
            } label: {
                Text("Find my strap")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LoopColor.night)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(LoopColor.text))
            }
            .buttonStyle(.plain)
        }
        .padding(LoopSpace.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LoopColor.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func check(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: LoopSpace.s) {
            Image(systemName: symbol)
                .foregroundStyle(LoopColor.muted)
                .frame(width: 24)
            Text(text)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
        }
    }
}

#if DEBUG
/// DEBUG-only: `--loop-preview <charged|steady|low|learning|nodata>` forces a recovery state over the
/// demo data, so every mood of Home can be checked in the simulator. No-op in Release.
enum LoopPreviewState: String {
    case charged, steady, low, learning, nodata

    static var requested: LoopPreviewState? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--loop-preview"), i + 1 < args.count else { return nil }
        return LoopPreviewState(rawValue: args[i + 1].lowercased())
    }

    func apply(to t: LoopToday) -> LoopToday {
        var t = t
        switch self {
        case .charged: t.recovery = .scored(84)
        case .steady: t.recovery = .scored(52)
        case .low: t.recovery = .scored(21)
        case .learning: t.recovery = .learning(nights: 2, of: 4)
        case .nodata:
            t.recovery = .noData; t.sleepMin = nil; t.sleepScore = nil; t.effort = nil; t.steps = nil
        }
        if CommandLine.arguments.contains("--loop-preview-activity") { t.effort = 58; t.steps = 13_277 }
        return t
    }
}
#endif

/// Press feedback for tappable Loop surfaces: a slight dim, no bounce.
struct LoopPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
