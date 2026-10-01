import Foundation
import WhoopProtocol

/// Which strap this phone wears, read from the registry's active device through Noop's canonical
/// brand-aware resolver (`DeviceFamily.forRegistryDevice`), so every spelling of a model label
/// resolves the same way.
@MainActor
enum LoopStrap {
    /// True only on positive evidence of a WHOOP 5.0 / MG. Noop's resolver falls back to `.whoop5`
    /// for the legacy "WHOOP" label and unknown labels (right for its skin-temp scale); Loop's
    /// "Not reliable on this strap yet" is a claim to the wearer, so an ambiguous label doesn't make it.
    static func isWhoop5(model: AppModel) -> Bool {
        // A live connection that has identified the hardware is the strongest evidence.
        if model.whoop5Detected { return true }
        guard let registry = model.deviceRegistry,
              let active = registry.devices.first(where: { $0.id == registry.activeDeviceId }) else {
            return false
        }
        let label = active.model.trimmingCharacters(in: .whitespaces)
        let ambiguous = label.isEmpty || label.caseInsensitiveCompare("WHOOP") == .orderedSame
        guard !ambiguous else { return false }
        return DeviceFamily.forRegistryDevice(model: label, brand: active.brand) == .whoop5
    }
}
