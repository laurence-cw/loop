import SwiftUI
import WhoopProtocol

/// Loop's Settings: only what a boy might change once a month. Fits one screen.
/// Everything is written through Noop's own stores and arming path (BehaviorStore, WindDownNudge,
/// ProfileStore, `AppModel.applySmartAlarm`), and every row re-reads from those stores after a write,
/// so Loop, the reminder and the strap can never disagree about a time.
struct LoopSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var behavior: BehaviorStore
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var live: LiveState

    @AppStorage(LoopPrefs.firstNameKey) private var firstName = ""
    @AppStorage(PuffinExperiment.defaultsKey) private var probesOn = false
    @State private var bedtimeReminder = WindDownNudge.isEnabled
    @State private var schoolWake = WindDownNudge.wakeMinutes
    @State private var weekendWake = LoopWake.weekendMinutes
    @State private var reminderDenied = false

    private var isWhoop5: Bool {
        #if DEBUG
        if CommandLine.arguments.contains("--loop-preview-whoop5") { return true }
        #endif
        return model.whoop5Detected
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("First name")
                    TextField("Your name", text: $firstName)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                }
                DatePicker("Date of birth", selection: $profile.dateOfBirth, in: ...Date(),
                           displayedComponents: .date)
            } header: { LoopListHeader("You") }
            .listRowBackground(LoopColor.surface)

            Section {
                Toggle("Wake-up buzz", isOn: $behavior.smartAlarmEnabled)
                timeRow("School days", minutes: Binding(
                    get: { schoolWake },
                    set: { LoopWake.setSchoolDays($0, keepingWeekend: weekendWake, behavior: behavior); reread() }))
                timeRow("Weekends", minutes: Binding(
                    get: { weekendWake },
                    set: { LoopWake.setWeekends($0); reread() }))
                Toggle("Bedtime reminder", isOn: $bedtimeReminder)
            } header: {
                LoopListHeader("Wake up")
            } footer: {
                Text(wakeFooter)
            }
            .listRowBackground(LoopColor.surface)

            Section {
                HStack {
                    Text(LoopStrapName.name(model: model, isWhoop5: isWhoop5))
                    Spacer()
                    Text(strapStatus).font(LoopFont.meta).foregroundStyle(LoopColor.muted)
                }
            } header: { LoopListHeader("Strap") }
            .listRowBackground(LoopColor.surface)

            Section {
                NavigationLink("Advanced") { LoopAdvancedView() }
                NavigationLink("About") { LoopAboutView() }
            }
            .listRowBackground(LoopColor.surface)
        }
        .loopListChrome(title: "Settings")
        .onChange(of: behavior.smartAlarmEnabled) { _, _ in model.applySmartAlarm() }
        .onChange(of: probesOn) { _, _ in model.applySmartAlarm() }
        .onChange(of: bedtimeReminder) { _, on in
            WindDownNudge.setEnabled(on) { outcome in
                if outcome == .denied { bedtimeReminder = false; reminderDenied = true }
            }
        }
        .alert("Notifications are off for Loop", isPresented: $reminderDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn them on in the phone's Settings to get a bedtime reminder.")
        }
        .onAppear {
            if LoopWake.alignAlarm(behavior: behavior) { model.applySmartAlarm() }
            schoolWake = WindDownNudge.wakeMinutes
            weekendWake = LoopWake.weekendMinutes
        }
    }

    /// After any write, show exactly what the stores now hold, and re-arm the strap from them.
    private func reread() {
        schoolWake = WindDownNudge.wakeMinutes
        weekendWake = LoopWake.weekendMinutes
        model.applySmartAlarm()
    }

    private func timeRow(_ title: String, minutes: Binding<Int>) -> some View {
        DatePicker(title, selection: Binding(
            get: { LoopWake.date(minutes.wrappedValue) },
            set: { minutes.wrappedValue = LoopWake.minutes($0) }
        ), displayedComponents: .hourAndMinute)
    }

    // MARK: Words

    /// The next buzz comes from the same pure function Noop arms the strap from, behind the same 5.0
    /// gate as Noop's alarm screen. The reminder time comes from the function that schedules it.
    private var wakeFooter: String {
        let now = Date()   // one clock for both lines
        var lines: [String] = []
        if behavior.smartAlarmEnabled {
            if isWhoop5 && !probesOn {
                lines.append("On a WHOOP 5.0 the buzz needs the 5.0 switch in Advanced.")
            } else if let next = AppModel.nextSmartAlarmDate(minutes: behavior.smartAlarmMinutes,
                                                             weekdays: behavior.smartAlarmWeekdays,
                                                             overrides: WindDownNudge.perDayWakeOverrides,
                                                             from: now) {
                lines.append("Next buzz \(LoopWake.dayName(next, now: now)) at \(LoopWake.time(next)).")
            }
        }
        if bedtimeReminder, let next = LoopWake.nextReminder(from: now) {
            lines.append("Bedtime reminder \(LoopWake.dayName(next, now: now, tonight: true)) at \(LoopWake.time(next)).")
        }
        return lines.isEmpty ? "Set your wake times, then turn on the buzz." : lines.joined(separator: " ")
    }

    /// The same words as Home's pill. Battery only while connected, when the figure is current.
    private var strapStatus: String {
        let status = LoopStatus.resolve(live: live, hasStrap: !(model.deviceRegistry?.devices.isEmpty ?? true))
        guard live.connected, let b = live.batteryPct else { return status.text }
        return "\(status.text) · \(Int(b.rounded()))%"
    }
}

/// School-day and weekend wake times, mapped onto Noop's alarm. The school-day time is Noop's base
/// alarm and usual wake time; the weekend time is an explicit per-day override on BOTH Saturday and
/// Sunday, so changing one never moves the other.
@MainActor
enum LoopWake {
    static let saturday = 7, sunday = 1

    static var weekendMinutes: Int {
        WindDownNudge.perDayWakeOverrides[saturday] ?? WindDownNudge.wakeMinutes
    }

    static func setSchoolDays(_ minutes: Int, keepingWeekend weekend: Int, behavior: BehaviorStore) {
        // Pin the weekend first, so moving school days can't drag it along through the base time.
        setWeekends(weekend)
        WindDownNudge.setWakeMinutes(minutes)
        behavior.smartAlarmMinutes = minutes
        behavior.smartAlarmWeekdays = []   // every day; the weekend has its own time
    }

    static func setWeekends(_ minutes: Int) {
        WindDownNudge.setWakeOverride(weekday: saturday, minutes: minutes)
        WindDownNudge.setWakeOverride(weekday: sunday, minutes: minutes)
    }

    /// Make the strap match Loop's two rows exactly: base alarm = usual wake time, no Monday-Friday
    /// overrides, every day enabled, and Saturday and Sunday both on the weekend time.
    /// Returns true when something changed, so the caller re-arms.
    @discardableResult
    static func alignAlarm(behavior: BehaviorStore) -> Bool {
        var changed = false
        if behavior.smartAlarmMinutes != WindDownNudge.wakeMinutes {
            behavior.smartAlarmMinutes = WindDownNudge.wakeMinutes
            changed = true
        }
        let overrides = WindDownNudge.perDayWakeOverrides
        for weekday in 2...6 where overrides[weekday] != nil {
            WindDownNudge.setWakeOverride(weekday: weekday, minutes: nil)
            changed = true
        }
        let weekend = weekendMinutes
        if overrides[saturday] != weekend || overrides[sunday] != weekend {
            setWeekends(weekend)
            changed = true
        }
        if !behavior.smartAlarmWeekdays.isEmpty {
            behavior.smartAlarmWeekdays = []
            changed = true
        }
        return changed
    }

    /// The next bedtime reminder that hasn't fired yet: the night before each wake, at the wake time
    /// minus Noop's sleep need and lead, the same arithmetic as `WindDownNudge.nudgeMinuteOfDay`.
    static func nextReminder(from now: Date) -> Date? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        for k in 0...8 {
            guard let wakeDay = cal.date(byAdding: .day, value: k, to: start) else { continue }
            let weekday = cal.component(.weekday, from: wakeDay)
            let wake = wakeDay.addingTimeInterval(TimeInterval(WindDownNudge.wakeMinutes(forWeekday: weekday) * 60))
            let reminder = wake.addingTimeInterval(-TimeInterval((WindDownNudge.sleepNeedMinutes
                                                                 + WindDownNudge.leadMinutes) * 60))
            if reminder > now { return reminder }
        }
        return nil
    }

    /// "today" / "tonight" / "tomorrow" / a weekday, for the footer.
    static func dayName(_ date: Date, now: Date, tonight: Bool = false) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return tonight ? "tonight" : "today" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: t) { return "tomorrow" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    /// A time in the phone's own clock format, the same as the time pickers above it show.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func date(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    static func minutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 7) * 60 + (c.minute ?? 0)
    }
}

/// The strap's name as the boy would say it: his nickname, else "WHOOP 4.0" / "WHOOP 5.0".
@MainActor
enum LoopStrapName {
    static func name(model: AppModel, isWhoop5: Bool) -> String {
        guard let r = model.deviceRegistry,
              let d = r.devices.first(where: { $0.id == r.activeDeviceId }) else { return "No strap paired" }
        if let nick = d.nickname, !nick.isEmpty { return nick }
        if isWhoop5 { return "WHOOP 5.0" }
        // An explicit registry label goes through Noop's one canonical resolver. The legacy "WHOOP"
        // label carries no family, so it falls back to the model the wearer picked when pairing.
        let label = d.model.trimmingCharacters(in: .whitespaces)
        let family: DeviceFamily?
        if !label.isEmpty, label.caseInsensitiveCompare("WHOOP") != .orderedSame {
            family = DeviceFamily.forRegistryDevice(model: label, brand: d.brand)
        } else {
            family = UserDefaults.standard.string(forKey: "selectedWhoopModel")
                .flatMap(WhoopModel.init(rawValue:))?.deviceFamily
        }
        switch family {
        case .whoop4?: return "WHOOP 4.0"
        case .whoop5?: return "WHOOP 5.0"
        default: return "WHOOP"
        }
    }
}

/// A list section header in Loop's voice: Regular weight, Muted, sentence case.
struct LoopListHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(LoopFont.rowTitle)
            .foregroundStyle(LoopColor.muted)
            .textCase(nil)
    }
}

extension View {
    /// The shared chrome for Loop's list screens: Night ground, dark system controls, Charged tint,
    /// and an Expanded inline title.
    func loopListChrome(title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(LoopColor.night.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { LoopBarTitle(title: title) }
                ToolbarItem(placement: .topBarTrailing) { LoopStrapGauges() }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .environment(\.colorScheme, .dark)
            .tint(LoopColor.charged)
    }
}
