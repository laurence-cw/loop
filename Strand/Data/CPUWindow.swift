import Foundation

/// The process's cumulative CPU seconds at recent moments, trimmed to the last
/// `RescoreBackgroundPolicy.cpuWindowSeconds`, so a background pace decision can see how much CPU the whole
/// process used over the last minute: what iOS judges, whichever thread spent it. Thread-safe.
final class CPUWindow: @unchecked Sendable {
    private var samples: [(cpu: Double, uptimeNanos: UInt64)] = []
    private let lock = NSLock()

    /// Adds a reading and returns the CPU seconds and wall seconds between the oldest reading still inside the
    /// window and this one. The first reading after a reset returns zeros.
    func record(cpu: Double, uptimeNanos: UInt64) -> (cpu: Double, wall: Double) {
        lock.lock()
        defer { lock.unlock() }
        samples.append((cpu, uptimeNanos))
        let window = UInt64(RescoreBackgroundPolicy.cpuWindowSeconds * 1_000_000_000)
        // Keep the newest reading at or before the window's start, so the span covers the whole minute.
        while samples.count > 2, uptimeNanos &- samples[1].uptimeNanos >= window { samples.removeFirst() }
        guard let first = samples.first, samples.count > 1 else { return (0, 0) }
        return (max(0, cpu - first.cpu), Double(uptimeNanos &- first.uptimeNanos) / 1_000_000_000)
    }

    func reset() {
        lock.lock()
        samples.removeAll()
        lock.unlock()
    }
}
