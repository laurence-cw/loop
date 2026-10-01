import SwiftUI

/// Loop's own settings keys. Stored apart from Noop's so Noop's data and backups are untouched.
enum LoopPrefs {
    static let firstNameKey = "loop.firstName"
}

/// Loop's root. Replaces Noop's tab shell on iPhone. Pairing still runs through Noop's setup
/// until Loop's own four-screen setup is built; Noop's terms screen is skipped by the owner's choice.
struct LoopRootView: View {
    @AppStorage("noop.onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            NavigationStack {
                LoopHomeView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            if !onboarded && !demoBypass {
                OnboardingWizard(onFinished: { onboarded = true })
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboarded)
    }

    /// DEBUG: `--demo-seed` skips setup so a seeded simulator build can be screenshotted.
    private var demoBypass: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-seed")
        #else
        return false
        #endif
    }
}
