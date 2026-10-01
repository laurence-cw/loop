import SwiftUI

/// Loop's own settings keys. Stored apart from Noop's so Noop's data and backups are untouched.
enum LoopPrefs {
    static let firstNameKey = "loop.firstName"
    /// Set when setup's "Pair later" was chosen, cleared once a strap bonds.
    static let pairLaterKey = "loop.pairLater"
}

/// Loop's root. Replaces Noop's tab shell on iPhone. First run shows Loop's four-screen setup;
/// Noop's terms screen is skipped by the owner's choice.
struct LoopRootView: View {
    @AppStorage("noop.onboarded") private var onboarded = false
    @EnvironmentObject private var repo: Repository

    var body: some View {
        ZStack {
            NavigationStack {
                LoopHomeView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            if !onboarded && !demoBypass {
                LoopSetupView(onFinished: { onboarded = true })
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboarded)
        // The launch duties of Noop's own root (RootTabView), which Loop replaces: read what's stored,
        // then Noop's on-launch backup catch-up (detached, utility priority, gated on its own toggle).
        .task {
            await repo.refresh()
            let backupRepo = repo
            Task.detached(priority: .utility) {
                await FolderBackup.catchUpIfDue(checkpoint: { await backupRepo.checkpointForBackup() })
            }
        }
    }

    /// DEBUG: `--demo-seed` skips setup so a seeded simulator build can be screenshotted.
    private var demoBypass: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-seed") && !CommandLine.arguments.contains("--loop-setup")
        #else
        return false
        #endif
    }
}
