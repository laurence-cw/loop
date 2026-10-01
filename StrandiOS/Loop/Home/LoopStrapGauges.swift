import SwiftUI

/// The strap at a glance, top right of every screen: when it last synced, and how much battery it
/// has left. Both read from the same `LoopStatus` funnel as the Home pill, on one clock, so the two can
/// never disagree. Tapping it opens "Find my strap".
struct LoopStrapGauges: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @State private var showFindStrap = false

    var body: some View {
        // Re-read every 30 seconds so "5m" ages on its own while the screen is open.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let status = previewStatus(context.date) ?? LoopStatus.resolve(live: live,
                                            hasStrap: !(model.deviceRegistry?.devices.isEmpty ?? true),
                                            now: context.date)
            Button { showFindStrap = true } label: {
                HStack(spacing: LoopSpace.xs) {
                    LoopSyncGauge(status: status, now: context.date)
                    LoopBatteryGauge(percent: previewBattery?.pct ?? battery,
                                     charging: previewBattery?.charging ?? (live.charging == true),
                                     live: previewBattery != nil || live.connected)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(LoopPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility(status, now: context.date))
            .accessibilityHint("Opens Find my strap")
            .sheet(isPresented: $showFindStrap) {
                LoopFindStrapSheet(status: status)
                    .presentationDetents([.medium])
            }
        }
    }

    /// The strap's own charge only: Noop's battery field can carry another device's number when a
    /// non-WHOOP source is active, so it is shown as the strap's only while a WHOOP is the active device.
    private var battery: Double? {
        live.activeIsWhoop ? live.batteryPct : nil
    }

    // DEBUG-only `--loop-preview-strap synced|lagged|charging|low`, for screenshots without a strap.
    private var previewArg: String? {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--loop-preview-strap"), i + 1 < args.count { return args[i + 1] }
        #endif
        return nil
    }

    private func previewStatus(_ now: Date) -> LoopStatus? {
        switch previewArg {
        case "synced", "charging", "low": return .synced(now.addingTimeInterval(-6 * 60))
        case "lagged": return .cantFind(lastSynced: now.addingTimeInterval(-5 * 3600))
        default: return nil
        }
    }

    private var previewBattery: (pct: Double, charging: Bool)? {
        switch previewArg {
        case "synced": return (64, false)
        case "lagged": return (31, false)
        case "charging": return (42, true)
        case "low": return (9, false)
        default: return nil
        }
    }

    private func accessibility(_ status: LoopStatus, now: Date) -> String {
        let battery = self.battery.map { "Strap battery \(Int($0.rounded())) percent\(live.charging == true ? ", charging" : "")" }
            ?? "Strap battery unknown"
        return "\(LoopSyncGauge.spoken(status, now: now)). \(battery)."
    }
}

/// Sync: a tick and how long ago when it's fresh, a spinner while syncing, a warning and the lag when
/// it's been too long.
struct LoopSyncGauge: View {
    let status: LoopStatus
    let now: Date

    var body: some View {
        HStack(spacing: 3) {
            icon
            Text(label)
                .font(Self.font)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(status.needsHelp ? LoopColor.text : LoopColor.muted)
                .contentTransition(.numericText())
        }
        .animation(LoopMotion.colourFade, value: status)
    }

    @ViewBuilder
    private var icon: some View {
        let symbol: String = {
            switch status {
            case .syncing: return "arrow.triangle.2.circlepath"
            case .synced: return "checkmark.circle"
            case .cantFind: return "exclamationmark.arrow.triangle.2.circlepath"
            case .bluetoothOff: return "antenna.radiowaves.left.and.right.slash"
            case .noStrap: return "plus.circle"
            }
        }()
        let image = Image(systemName: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(status.needsHelp ? LoopColor.text : LoopColor.muted)
        if case .syncing = status, #available(iOS 18.0, *) {
            image.symbolEffect(.rotate, options: .repeat(.continuous))
        } else {
            image
        }
    }

    private var label: String {
        switch status {
        case .syncing: return "Syncing"
        case .synced(let d): return Self.age(d, now: now)
        case .cantFind(let last?): return Self.age(last, now: now)
        // The icon says which; the words are in the pill under the ring and in VoiceOver.
        case .cantFind(nil), .bluetoothOff, .noStrap: return "–"
        }
    }

    /// Small and quiet: caption2, Expanded, monospaced digits.
    static let font = Font.system(.caption2, weight: .medium).width(.expanded).monospacedDigit()

    /// "Now", "12m", "3h", "2d": how long since the last sync.
    static func age(_ d: Date, now: Date) -> String {
        let minutes = max(Int(now.timeIntervalSince(d) / 60), 0)
        switch minutes {
        case ..<2: return "Now"
        case ..<60: return "\(minutes)m"
        case ..<(48 * 60): return "\(minutes / 60)h"
        default: return "\(minutes / (24 * 60))d"
        }
    }

    static func spoken(_ status: LoopStatus, now: Date) -> String {
        switch status {
        case .syncing: return "Syncing"
        case .synced(let d): return age(d, now: now) == "Now" ? "Synced just now" : "Synced \(age(d, now: now)) ago"
        case .cantFind(let last?): return "Not synced for \(age(last, now: now))"
        case .cantFind(nil): return "Not synced yet"
        case .bluetoothOff: return "Bluetooth is off"
        case .noStrap: return "No strap paired"
        }
    }
}

/// A small battery drawn to the strap's exact charge, with the percentage beside it. A bolt while it
/// charges. Dimmed when the strap isn't connected, because then it's the last reading, not a live one.
struct LoopBatteryGauge: View {
    let percent: Double?
    let charging: Bool
    let live: Bool

    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 19
    private var bodySize: CGSize { CGSize(width: width, height: width * 0.5) }

    var body: some View {
        let f = min(max((percent ?? 0) / 100, 0), 1)
        let colour = percent == nil || !live ? LoopColor.muted : LoopColor.text
        HStack(spacing: 4) {
            HStack(spacing: 1.5) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .strokeBorder(colour.opacity(0.55), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colour)
                        .frame(width: max((bodySize.width - 4) * f, f > 0 ? 2 : 0))
                        .padding(2)
                }
                .frame(width: bodySize.width, height: bodySize.height)
                // The terminal nub.
                RoundedRectangle(cornerRadius: 1)
                    .fill(colour.opacity(0.55))
                    .frame(width: 2, height: bodySize.height * 0.4)
            }
            // Charging: a bolt beside the battery, in Charged, so it shows at any level.
            if charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(LoopColor.charged)
            }
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "–")
                .font(LoopSyncGauge.font)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(colour)
                .contentTransition(.numericText())
        }
        .animation(LoopMotion.fill, value: f)
    }
}

extension View {
    /// The strap gauges at the trailing end of a pushed screen's bar.
    func loopStrapGaugesToolbar() -> some View {
        toolbar {
            LoopGaugesToolbarItem()
        }
    }
}

/// The gauges as a bar item, without the glass capsule iOS 26 draws behind bar items.
struct LoopGaugesToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { LoopStrapGauges() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { LoopStrapGauges() }
        }
    }
}
