import SwiftUI
import UIKit

/// Loop's Home. Above the fold: the status pill, the day, the loop ring and one sentence. Nothing else.
/// Swipe the ring sideways to look back over the last two weeks. Below it: one quiet row per section.
struct LoopHomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var live: LiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage(LoopPrefs.firstNameKey) private var firstName = ""
    /// Today, live. The section screens are always today and share this.
    @State private var today = LoopToday.empty
    /// Earlier days, from Noop's stored rows, keyed by day.
    @State private var past: [String: LoopToday] = [:]
    @State private var pages: [Page] = []
    /// The page in view. Nil until the pages exist; then today's key unless swiped back.
    @State private var selected: String?
    @State private var showFindStrap = false
    @State private var openRecovery = false
    @State private var openSleep = false
    @State private var openActivity = false
    @State private var openSettings = false
    @State private var openBreathe = false
    @State private var openWeek = false
    private static let rowsAnchor = "loop.home.rows"

    struct Page: Equatable {
        let key: String
        let date: Date
        let isToday: Bool
    }

    private var status: LoopStatus {
        LoopStatus.resolve(live: live, hasStrap: !(model.deviceRegistry?.devices.isEmpty ?? true))
    }

    private var todayKey: String? { pages.last?.key }
    private var shownPage: Page? { pages.first(where: { $0.key == selected }) ?? pages.last }
    private var isShowingToday: Bool { shownPage?.isToday ?? true }
    /// The day the rows below the fold describe: whichever page is in view.
    private var shown: LoopToday { data(for: shownPage) }

    private func data(for page: Page?) -> LoopToday {
        guard let page, !page.isToday else { return today }
        return past[page.key] ?? .empty
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // The rows follow straight on from the sentence (or the pill) with one fixed gap,
                        // rather than being pushed below the fold, which left a screen-high hole on a
                        // shorter iPhone.
                        hero
                        rows
                            .padding(.top, LoopSpace.l)
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
            let newPages = LoopPastDayReader.keys(repo: repo).enumerated().map { i, p in
                Page(key: p.key, date: p.date, isToday: i == LoopPastDayReader.span - 1)
            }
            today = await LoopTodayReader.read(repo: repo, profile: profile)
            past = await LoopPastDayReader.read(repo: repo, dayKeys: newPages.dropLast().map(\.key), age: profile.age)
            #if DEBUG
            if let preview = LoopPreviewState.requested { today = preview.apply(to: today) }
            if CommandLine.arguments.contains("--loop-preview-days") { past = LoopPreviewState.pastDays(newPages) }
            #endif
            if pages != newPages {
                // A new day has started (or first load): land on today.
                pages = newPages
                selected = newPages.last?.key
            }
            #if DEBUG
            if CommandLine.arguments.contains("--loop-open-recovery") { openRecovery = true }
            if CommandLine.arguments.contains("--loop-open-sleep") { openSleep = true }
            if CommandLine.arguments.contains("--loop-open-activity") { openActivity = true }
            if CommandLine.arguments.contains("--loop-open-settings") { openSettings = true }
            if CommandLine.arguments.contains("--loop-open-breathe") { openBreathe = true }
            if CommandLine.arguments.contains("--loop-open-week") { openWeek = true }
            if let i = CommandLine.arguments.firstIndex(of: "--loop-day-back"), i + 1 < CommandLine.arguments.count,
               let back = Int(CommandLine.arguments[i + 1]), back < pages.count {
                let key = pages[pages.count - 1 - back].key
                // After the pager has laid out, the same way a tap on the chevron moves it.
                try? await Task.sleep(for: .seconds(1))
                step(to: pages.firstIndex(where: { $0.key == key }) ?? pages.count - 1)
            }
            #endif
        }
        // Pull down: ask for a sync through Noop's rate-limited foreground trigger (not the forced
        // manual sync, which pauses a 4.0's live heart rate), or look for the strap when it isn't
        // connected; then re-read what's stored, the way Noop's own Today refresh does.
        .refreshable {
            if live.connected && live.bonded {
                model.ble.requestSync(.foreground)
            } else if !status.isNeedsPairing {
                model.scan()
            }
            await repo.refresh()
        }
        .navigationDestination(isPresented: $openRecovery) { LoopRecoveryView(today: $today) }
        .navigationDestination(isPresented: $openSleep) { LoopSleepView(today: $today) }
        .navigationDestination(isPresented: $openActivity) { LoopActivityView(today: $today) }
        .navigationDestination(isPresented: $openSettings) { LoopSettingsView() }
        .navigationDestination(isPresented: $openBreathe) { LoopBreatheView() }
        .navigationDestination(isPresented: $openWeek) { LoopWeekView(today: $today) }
        .sheet(isPresented: $showFindStrap) {
            LoopFindStrapSheet(status: status)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Above the fold

    /// Logo, strap gauges and Settings at the top; the day, the ring, its two values and the sentence sit together as one group,
    /// centred in what's left. The ring, values and sentence page sideways together, one day per page.
    private var hero: some View {
        VStack(spacing: 0) {
            // The logo on the left; the strap's sync and battery on the right beside Settings, where they
            // sit on every other screen too (those screens need the left for their back button).
            HStack(spacing: LoopSpace.xs) {
                LoopLogo()
                Spacer(minLength: LoopSpace.xs)
                LoopStrapGauges()
                Button { openSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(LoopColor.muted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Settings")
            }
            .padding(.leading, LoopSpace.s)
            .padding(.trailing, LoopSpace.xs)
            .padding(.top, LoopSpace.xs)

            if status == .bluetoothOff {
                LoopBluetoothCard()
                    .padding(.horizontal, LoopSpace.edge)
                    .padding(.top, LoopSpace.s)
            }

            dayHeader
                .padding(.top, LoopSpace.m)
                .padding(.horizontal, LoopSpace.edge)
                .padding(.bottom, LoopSpace.m)

            if pages.isEmpty {
                dayPage(Page(key: "", date: .now, isToday: true))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(pages, id: \.key) { page in
                            dayPage(page)
                                .containerRelativeFrame(.horizontal)
                                .id(page.key)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selected)
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.trailing)
                .sensoryFeedback(.selection, trigger: selected)
            }

            // Under the ring, and only when there's something to do: pair, find or switch Bluetooth on.
            // When all is well the gauges at the top already say so.
            if status.needsHelp {
                LoopStatusPill(status: status) { showFindStrap = true }
                    .padding(.top, LoopSpace.m)
                    .transition(.opacity)
            }
        }
    }

    /// "Today" / "Yesterday" / "Monday" with a step either way, so the days can be reached without
    /// swiping (and by VoiceOver).
    private var dayHeader: some View {
        let index = pages.firstIndex(where: { $0.key == shownPage?.key }) ?? max(pages.count - 1, 0)
        return HStack(spacing: LoopSpace.xs) {
            stepButton("chevron.left", label: "Earlier day", enabled: index > 0) { step(to: index - 1) }
            Text(shownPage.map { Self.dayTitle($0) } ?? "Today")
                .font(LoopFont.inlineTitle)
                .foregroundStyle(isShowingToday ? LoopColor.text : LoopColor.muted)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: selected)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            stepButton("chevron.right", label: "Later day", enabled: index < pages.count - 1) { step(to: index + 1) }
        }
        .frame(maxWidth: 290)
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LoopColor.muted)
                .frame(width: 44, height: 44)
        }
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func step(to i: Int) {
        guard pages.indices.contains(i) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { selected = pages[i].key }
    }

    /// One day: the ring (tappable today, opening Recovery), its two values and the sentence.
    private func dayPage(_ page: Page) -> some View {
        let t = data(for: page)
        return VStack(spacing: 0) {
            Button { openRecovery = true } label: {
                LoopRing(today: t, sleepFraction: sleepFraction(t), effortFraction: effortFraction(t))
                    .frame(maxWidth: 260)
                    .contentShape(Circle())
            }
            .buttonStyle(LoopPressStyle())
            .disabled(!page.isToday)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ringAccessibilityLabel(t))
            .accessibilityHint(page.isToday ? "Opens Recovery" : "")

            arcFeet(t)
                .frame(maxWidth: 290)
                .padding(.top, LoopSpace.s)

            Text(sentence(t, page: page))
                .font(LoopFont.sentence)
                .foregroundStyle(LoopColor.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, LoopSpace.xl)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LoopSpace.l)
    }

    /// Each arc's value at its outer foot, marked by its section's symbol: sleep under the left arc,
    /// activity under the right, always on one line so the two read as a pair. Each shrinks a little
    /// before it would wrap; only the accessibility text sizes stack them.
    @ViewBuilder
    private func arcFeet(_ t: LoopToday) -> some View {
        let sleep = footValue(symbol: "moon.fill", colour: LoopColor.signal, value: t.sleepMin,
                              format: { LoopFormat.duration($0 * 60) })
        let effort = footValue(symbol: "figure.walk", colour: LoopColor.pulse, value: t.effort,
                               format: { "\(Int($0.rounded()))" }, unit: "/100")
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: LoopSpace.xs) {
                    sleep.frame(maxWidth: .infinity, alignment: .leading)
                    effort.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: LoopSpace.s) {
                    sleep
                    Spacer(minLength: LoopSpace.s)
                    effort
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// One arc's value, counting up as it appears.
    private func footValue(symbol: String, colour: Color, value: Double?, format: @escaping (Double) -> String,
                           unit: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(colour)
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    LoopCountUp(value: value, format: format)
                        .foregroundStyle(LoopColor.text)
                    if let unit {
                        Text(unit).font(.footnote.weight(.medium)).foregroundStyle(LoopColor.muted)
                    }
                }
                .font(LoopFont.rowValue)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            } else {
                Text("No data")
                    .font(LoopFont.rowValue)
                    .foregroundStyle(LoopColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    // MARK: Below the fold

    /// The rows follow the day in view. The sections themselves are today's, so an earlier day's rows
    /// are for reading, not opening.
    private var rows: some View {
        let t = shown, opens = isShowingToday
        return VStack(spacing: LoopSpace.s) {
            Button { openRecovery = true } label: {
                LoopSectionRow(symbol: "bolt.fill", title: "Recovery", colour: recoveryColour(t),
                               word: t.recovery.score.map { RecoveryBand(score: $0).word },
                               value: t.recovery.score.map { "\($0)" }, opens: opens, wordOnly: true)
            }
            .buttonStyle(LoopPressStyle())
            .disabled(!opens)
            Button { openSleep = true } label: {
                LoopSectionRow(symbol: "moon.fill", title: "Sleep", colour: LoopColor.signal,
                               word: t.sleepScore.map { ScoreWord.word(for: $0) },
                               value: t.sleepMin.map { LoopFormat.duration($0 * 60) }, opens: opens, wordOnly: true)
            }
            .buttonStyle(LoopPressStyle())
            .disabled(!opens)
            Button { openActivity = true } label: {
                LoopSectionRow(symbol: "figure.walk", title: "Activity", colour: LoopColor.pulse,
                               word: t.effort.map { ScoreWord.word(for: Int($0.rounded())) },
                               value: t.effort.map { "\(Int($0.rounded()))" },
                               detail: t.steps.map { "\(LoopFormat.steps($0)) steps" }, opens: opens, wordOnly: true)
            }
            .buttonStyle(LoopPressStyle())
            .disabled(!opens)
            // The weekly round-up: the same whichever day is in view, so it always opens.
            Button { openWeek = true } label: {
                LoopSectionRow(symbol: "calendar", title: "Your week", colour: LoopColor.text,
                               word: nil, value: nil, detail: "Best night, hardest day, averages",
                               opens: true, quiet: true)
            }
            .buttonStyle(LoopPressStyle())
        }
        .animation(.easeInOut(duration: 0.25), value: selected)
    }

    // MARK: Words

    /// "Today" / "Yesterday" / "Monday" this past week / "Mon 21 Sep" before that.
    static func dayTitle(_ page: Page) -> String {
        if page.isToday { return "Today" }
        let cal = Calendar.current
        let back = cal.dateComponents([.day], from: cal.startOfDay(for: page.date),
                                      to: cal.startOfDay(for: Repository.logicalDay(.now))).day ?? 0
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        switch back {
        case 1: return "Yesterday"
        case 2...6: f.dateFormat = "EEEE"
        default: f.dateFormat = "EEE d MMM"
        }
        return f.string(from: page.date)
    }

    private func sentence(_ t: LoopToday, page: Page) -> String {
        guard page.isToday else { return pastSentence(t, page: page) }
        let hello = LoopFormat.greeting(name: firstName)
        switch t.recovery {
        case .scored(let s), .carried(let s):
            return "\(hello) \(RecoveryBand(score: s).line)"
        case .learning(let nights, let of):
            let left = max(of - nights, 1)
            return "\(hello) Getting to know you. Give it \(left) more \(left == 1 ? "night" : "nights")."
        case .noData:
            return "\(hello) No score yet today. Was the strap off last night?"
        }
    }

    /// An earlier day, said plainly in the past tense.
    private func pastSentence(_ t: LoopToday, page: Page) -> String {
        let title = Self.dayTitle(page)
        let when = title == "Yesterday" ? "Yesterday" : "On \(title)"
        guard let s = t.recovery.score else { return "No score for \(title == "Yesterday" ? "yesterday" : title)." }
        switch RecoveryBand(score: s) {
        case .charged: return "\(when) you were fully charged."
        case .steady: return "\(when) you were half charged."
        case .low: return "\(when) you were running low."
        }
    }

    /// Recovery's colour is the day's band. With no score yet it takes Glow, Loop's in-between colour,
    /// so the row still reads as Recovery rather than switched off.
    private func recoveryColour(_ t: LoopToday) -> Color {
        t.recovery.score.map { RecoveryBand(score: $0).colour } ?? LoopColor.glow
    }

    private func sleepFraction(_ t: LoopToday) -> Double? {
        t.sleepMin.map { $0 / max(t.sleepNeedMin, 1) }
    }

    private func effortFraction(_ t: LoopToday) -> Double? {
        t.effort.map { $0 / 100 }
    }

    private func ringAccessibilityLabel(_ t: LoopToday) -> String {
        var parts: [String] = []
        switch t.recovery {
        case .scored(let s), .carried(let s):
            parts.append("Recovery \(s) out of 100, \(RecoveryBand(score: s).word)")
        case .learning(let n, let of):
            parts.append("Recovery: getting to know you, \(n) of \(of) nights")
        case .noData:
            parts.append("Recovery: no score")
        }
        if let m = t.sleepMin {
            parts.append("Sleep \(LoopFormat.duration(m * 60)) of \(LoopFormat.duration(t.sleepNeedMin * 60)) needed")
        } else {
            parts.append("Sleep: no data")
        }
        if let e = t.effort { parts.append("Effort \(Int(e.rounded())) out of 100") }
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
    /// A row with no value to show (e.g. the weekly round-up): no "No data" either.
    var quiet: Bool = false
    /// Just the word ("Charged"), no number: the ring above and the section itself carry the numbers.
    /// Falls back to the number when there's no word yet (e.g. hours slept before Noop scores the night).
    var wordOnly: Bool = false

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
                    // Never hyphenated across lines ("Re-cov-ery"); shrinks a touch at big text sizes.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)   // the title keeps its room; the value shrinks first
                if let detail {
                    Text(detail)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(LoopColor.muted)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: LoopSpace.xs)
            HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
                if let value {
                    // One Text, so the word and the number shrink together and keep one baseline.
                    Group {
                        if wordOnly, let word {
                            Text(word).foregroundStyle(colour)
                        } else {
                            (Text(word.map { "\($0) " } ?? "").foregroundStyle(colour)
                             + Text(value).foregroundStyle(LoopColor.text))
                        }
                    }
                    .font(LoopFont.rowValue)
                } else if !quiet {
                    Text("No data")
                        .font(LoopFont.rowValue)
                        .foregroundStyle(LoopColor.muted)
                }
            }
            // "Charged 84" stays on one line: shrink slightly rather than wrap.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
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

/// The status pill under Home's ring, shown only when something needs doing. Battery and sync live
/// in the gauges at the top.
/// It never borrows Recovery's colours: Recovery is the only thing in Loop that changes colour.
struct LoopStatusPill: View {
    let status: LoopStatus
    let onHelp: () -> Void

    var body: some View {
        Button(action: onHelp) {
            HStack(spacing: LoopSpace.xs) {
                icon
                Text(status.text)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(status.needsHelp ? LoopColor.text : LoopColor.muted)
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
        case .noStrap:
            Image(systemName: "plus.circle").font(.footnote).foregroundStyle(LoopColor.text)
        case .cantFind, .bluetoothOff:
            Image(systemName: "exclamationmark.circle").font(.footnote).foregroundStyle(LoopColor.text)
        case .needsPairing:
            Image(systemName: "exclamationmark.triangle").font(.footnote).foregroundStyle(LoopColor.text)
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

/// "Find my strap": one button plus three quick checks. When Noop has stopped reconnecting and says
/// why (the pairing was reset, or the strap refuses to pair), its own guide replaces the checks,
/// because the checks wouldn't fix it.
struct LoopFindStrapSheet: View {
    let status: LoopStatus
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.m) {
            VStack(alignment: .leading, spacing: LoopSpace.xs) {
                Text(status.text)
                    .font(LoopFont.title)
                    .foregroundStyle(LoopColor.text)
                if case .cantFind(let last?) = status {
                    Text("Last synced \(LoopFormat.clock(last)).")
                        .font(LoopFont.body)
                        .foregroundStyle(LoopColor.muted)
                }
            }
            if case .needsPairing(let guide) = status {
                ScrollView {
                    Text(guide)
                        .font(LoopFont.body)
                        .foregroundStyle(LoopColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: LoopSpace.s) {
                    check("battery.100percent", "Is it charged?")
                    check("antenna.radiowaves.left.and.right", "Is it nearby, on your wrist?")
                    check("dot.radiowaves.right", "Is Bluetooth on?")
                }
                Spacer(minLength: 0)
            }
            Button {
                // Noop's user-initiated connect: it also clears Noop's give-up and reconnect pause.
                model.scan()
                dismiss()
            } label: {
                Text(status.isNeedsPairing ? "Try again" : "Find my strap")
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

    /// DEBUG-only `--loop-preview-days`: a varied fortnight behind today, one night missing.
    static func pastDays(_ pages: [LoopHomeView.Page]) -> [String: LoopToday] {
        let scores = [71, 44, 88, 63, 29, 55, 80, 47, 92, 38, 66, 74, 58]
        var out: [String: LoopToday] = [:]
        for (i, page) in pages.dropLast().enumerated() {
            var t = LoopToday()
            if i == 9 { out[page.key] = t; continue }
            let s = scores[i % scores.count]
            t.recovery = .scored(s)
            t.sleepMin = 380 + Double((s * 7) % 140)
            t.sleepScore = min(s + 8, 100)
            t.effort = Double(30 + (s * 3) % 55)
            t.steps = 6_000 + (s * 137) % 9_000
            out[page.key] = t
        }
        return out
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
