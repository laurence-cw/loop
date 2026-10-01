import Foundation

/// The one strap status Loop shows, in the gauges at the top and the pill under Home's ring.
/// Read-only over Noop's `LiveState`.
enum LoopStatus: Equatable {
    case syncing
    case synced(Date)
    /// Not connected for a while; the pill becomes tappable with "Find my strap".
    case cantFind(lastSynced: Date?)
    case bluetoothOff
    case noStrap
    /// Noop has stopped trying on its own and says why: the strap's pairing was reset (firmware update,
    /// the WHOOP app re-bonding it), it refuses to pair, or reconnecting is paused after repeated drops.
    /// Carries Noop's own step-by-step guide, which is the actual fix; a generic checklist isn't.
    case needsPairing(guide: String)

    /// While disconnected, "Synced" is kept only this long: a brief drop and Noop's own reconnect are
    /// normal and shouldn't flash a warning, but anything longer is said plainly.
    static let disconnectedGrace: TimeInterval = 15 * 60

    @MainActor
    static func resolve(live: LiveState, hasStrap: Bool, now: Date = .now) -> LoopStatus {
        if live.lastSyncError?.hasPrefix("Bluetooth is off") == true { return .bluetoothOff }
        // Noop's guides first: when one is up, Noop isn't reconnecting by itself, so nothing else is true.
        if let guide = live.reconnectGuide { return .needsPairing(guide: guide) }
        if let hint = live.pairingHint, !live.bonded { return .needsPairing(guide: hint) }
        // Setup's "Pair later": name the next step, not a fault, until a strap bonds.
        let pairLater = UserDefaults.standard.bool(forKey: LoopPrefs.pairLaterKey)
        guard hasStrap, !(pairLater && !live.bonded) else { return .noStrap }
        if live.backfilling { return .syncing }
        let last = live.lastSyncedAt.map { Date(timeIntervalSince1970: $0) }
        if live.connected, let last { return .synced(last) }
        if !live.connected, let last, now.timeIntervalSince(last) < disconnectedGrace { return .synced(last) }
        return .cantFind(lastSynced: last)
    }

    var text: String {
        switch self {
        case .syncing: return "Syncing"
        case .synced(let d): return "Synced \(LoopFormat.clock(d))"
        case .cantFind: return "Can't find your strap"
        case .bluetoothOff: return "Bluetooth is off"
        case .noStrap: return "Pair your strap"
        case .needsPairing: return "Your strap needs pairing again"
        }
    }

    var isNeedsPairing: Bool {
        if case .needsPairing = self { return true }
        return false
    }

    var needsHelp: Bool {
        switch self {
        case .cantFind, .bluetoothOff, .noStrap, .needsPairing: return true
        case .syncing, .synced: return false
        }
    }
}
