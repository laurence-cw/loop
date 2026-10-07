import Foundation
import UIKit

/// One strap-log line every 30 seconds with this process's CPU use over that half-minute, whether the app
/// is in the background, and whether a re-score is running. iOS kills a backgrounded app that holds more
/// than 80% of a core over a minute, and its own reports of that arrive a day later without saying what was
/// running; this puts the minute before a kill in the same log as everything else.
///
/// Costs one `getrusage` and one log line per 30 seconds. Starts once per process.
@MainActor
enum LoopCPUProbe {
    private static var timer: Timer?

    /// A new build of the app starts its background-attempt count afresh: the count describes what this
    /// build could not finish, and a build that scores faster should get its own background tries rather
    /// than inherit the old build's stand-down. Keyed on the executable's modification date, which every
    /// install changes.
    private static func resetBackgroundAttemptsOnNewBuild() {
        let key = "loop.lastBuildStamp"
        guard let url = Bundle.main.executableURL,
              let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return }
        let stamp = String(Int(date.timeIntervalSince1970))
        if UserDefaults.standard.string(forKey: key) != stamp {
            UserDefaults.standard.set(stamp, forKey: key)
            UserDefaults.standard.set(0, forKey: RescoreBackgroundScheduler.unfinishedBackgroundAttemptsKey)
        }
    }

    static func start(model: AppModel) {
        guard timer == nil else { return }
        resetBackgroundAttemptsOnNewBuild()
        // Background pace decisions go to the same log, so a kill can be read against what the pass was doing.
        RescoreBackgroundScheduler.paceLog = { [weak model] line in
            Task { @MainActor in model?.live.append(log: AppModel.stamped(line)) }
        }
        var lastCPU = RescoreBackgroundScheduler.processCPUSeconds()
        var lastAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak model] _ in
            MainActor.assumeIsolated {
                guard let model else { return }
                let now = Date()
                let cpu = RescoreBackgroundScheduler.processCPUSeconds()
                if let cpu, let last = lastCPU {
                    let span = now.timeIntervalSince(lastAt)
                    let used = max(0, cpu - last)
                    let share = span > 0 ? Int((used / span * 100).rounded()) : 0
                    let state = UIApplication.shared.applicationState == .active ? "fg" : "bg"
                    let pass = model.intelligence.computing ? "rescore" : "idle"
                    model.live.append(log: AppModel.stamped(
                        String(format: "cpu probe: %.1fs in %.0fs (%d%%) %@ %@", used, span, share, state, pass)))
                }
                lastCPU = cpu
                lastAt = now
            }
        }
    }
}
