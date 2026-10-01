import Foundation

/// The one-line strap status Loop shows in its pill. Read-only over Noop's `LiveState`.
enum LoopStatus: Equatable {
    case syncing
    case synced(Date)
    /// Not connected for a while; the pill becomes tappable with "Find my strap".
    case cantFind(lastSynced: Date?)
    case bluetoothOff
    case noStrap

    /// After this long without a connection or a sync, Loop stops saying "Synced" and offers help.
    static let staleAfter: TimeInterval = 3 * 60 * 60

    @MainActor
    static func resolve(live: LiveState, hasStrap: Bool, now: Date = .now) -> LoopStatus {
        if live.lastSyncError?.hasPrefix("Bluetooth is off") == true { return .bluetoothOff }
        guard hasStrap else { return .noStrap }
        if live.backfilling { return .syncing }
        let last = live.lastSyncedAt.map { Date(timeIntervalSince1970: $0) }
        if live.connected, let last { return .synced(last) }
        if let last, now.timeIntervalSince(last) < staleAfter { return .synced(last) }
        return .cantFind(lastSynced: last)
    }

    var text: String {
        switch self {
        case .syncing: return "Syncing"
        case .synced(let d): return "Synced \(LoopFormat.clock(d))"
        case .cantFind: return "Can't find your strap"
        case .bluetoothOff: return "Bluetooth is off"
        case .noStrap: return "No strap paired"
        }
    }

    var needsHelp: Bool {
        switch self {
        case .cantFind, .bluetoothOff, .noStrap: return true
        case .syncing, .synced: return false
        }
    }
}
