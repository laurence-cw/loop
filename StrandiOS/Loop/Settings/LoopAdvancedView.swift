import SwiftUI
import StrandAnalytics

/// Only needed to fix something. One tap deeper than Settings, and allowed to scroll.
/// Every action goes through Noop's own call for it.
struct LoopAdvancedView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState

    @AppStorage(PuffinExperiment.defaultsKey) private var probesOn = false
    @State private var confirmRestart = false
    @State private var confirmRestore = false
    @State private var confirmRecalibrate = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var showSteps = false
    @State private var busy = false
    @State private var message: (title: String, body: String)?

    var body: some View {
        List {
            Section {
                Button("Find my strap") { model.scan() }
                // Noop offers a restart only to a connected strap that isn't a 4.0.
                if live.connected && model.whoop5Detected {
                    Button("Restart strap") { confirmRestart = true }
                }
                // Noop renames only a connected 4.0; the strap reboots to apply it.
                if live.connected && !model.whoop5Detected {
                    Button("Rename strap") { newName = live.advertisingName ?? ""; renaming = true }
                }
                Toggle("WHOOP 5.0 switch", isOn: $probesOn)
                if let fw = live.strapFirmware {
                    LabeledContent("Firmware", value: fw)
                }
            } header: {
                LoopListHeader("Strap")
            } footer: {
                Text("The 5.0 switch is needed for the wake-up buzz on a WHOOP 5.0. It turns on NOOP's experimental strap features.")
            }
            .listRowBackground(LoopColor.surface)

            Section {
                Button("Export a backup") { export() }
                Button("Restore from a backup") { confirmRestore = true }
                Button("Export as a spreadsheet") { exportCSV() }
                Button("Share strap log") { shareLog() }
                NavigationLink("Storage") { StorageView() }
            } header: {
                LoopListHeader("Your data")
            } footer: {
                Text("A backup is everything Loop has stored, in one file. Keep it somewhere safe.")
            }
            .listRowBackground(LoopColor.surface)

            Section {
                Button("Re-learn your normal") { confirmRecalibrate = true }
                Button("Steps calibration") { showSteps = true }
            } header: {
                LoopListHeader("Scores")
            } footer: {
                Text("Re-learning starts your normal again from tonight. Your history is kept.")
            }
            .listRowBackground(LoopColor.surface)

            if let days = IOSDiagnostics.capture().expiryDaysRemaining() {
                Section {
                    LabeledContent("Needs refreshing", value: days <= 0 ? "Now" : "In \(days) \(days == 1 ? "day" : "days")")
                } header: {
                    LoopListHeader("App")
                } footer: {
                    Text("Loop is refreshed from the Mac every 7 days.")
                }
                .listRowBackground(LoopColor.surface)
            }
        }
        .loopListChrome(title: "Advanced")
        .disabled(busy)
        .sheet(isPresented: $showSteps) {
            StepsCalibrationSheet(repo: model.repo, onClose: { showSteps = false })
        }
        .alert("Rename strap", isPresented: $renaming) {
            TextField("Strap name", text: $newName)
            Button("Rename") { model.ble.renameStrap(newName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The strap restarts to use its new name.")
        }
        .onChange(of: probesOn) { _, _ in model.applySmartAlarm() }
        .confirmationDialog("Restart your strap?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart") { model.rebootStrap() }
        } message: {
            Text("It disconnects for a minute and reconnects on its own. Nothing is lost.")
        }
        .confirmationDialog("Restore from a backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Choose backup", role: .destructive) { restore() }
        } message: {
            Text("This replaces everything Loop has stored with the backup.")
        }
        .confirmationDialog("Re-learn your normal?", isPresented: $confirmRecalibrate, titleVisibility: .visible) {
            Button("Re-learn") { recalibrate() }
        } message: {
            Text("Your scores start learning again from tonight. It takes a few nights to settle.")
        }
        .alert(message?.title ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message?.body ?? "")
        }
    }

    // MARK: Actions (Noop's own calls)

    private func export() {
        busy = true
        Task {
            let result = await DataBackup.runExport(checkpoint: { await model.repo.checkpointForBackup() })
            busy = false
            show(result)
        }
    }

    private func restore() {
        busy = true
        Task {
            // A backup the owner exported themselves is trusted, so no second size prompt.
            let result = await DataBackup.runImport(allowOversize: true)
            busy = false
            show(result)
        }
    }

    private func exportCSV() {
        busy = true
        Task {
            let result = await CsvExport.run(repo: model.repo)
            busy = false
            switch result {
            case .cancelled: return
            case .exported(let url): message = ("Spreadsheet saved", "Saved as \(url.lastPathComponent).")
            case .failure(let m): message = ("That didn't work", m)
            }
        }
    }

    private func shareLog() {
        Task {
            let extra = await DebugDataDiagnostics.dynamicLines(repo: model.repo)
            FileExport.exportText(live.exportableLogText(extraHeaderLines: extra),
                                  suggestedName: FileExport.timestampedName("loop-strap-log", ext: "txt"))
        }
    }

    private func recalibrate() {
        Baselines.recalibrateRecoveryBaselines()
        Task {
            await model.intelligence.analyzeRecent()
            await model.repo.refresh()
        }
        message = ("Re-learning your normal", "Loop starts again from tonight. Give it a few nights.")
    }

    private func show(_ result: DataBackup.BackupResult) {
        switch result {
        case .cancelled:
            return
        case .exported(let url), .exportedOversize(let url, _, _):
            message = ("Backup saved", "Saved as \(url.lastPathComponent).")
        case .imported:
            message = ("Backup restored", "Close Loop and open it again to see your data.")
        default:
            message = ("That didn't work", "The backup couldn't be used. Try another file.")
        }
    }
}

/// About: the one place Loop says its scores are estimates, plus Noop's credits and licence.
struct LoopAboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        List {
            Section {
                Text("Loop's scores are estimates from your strap, worked out on this phone. They're a guide, not medical advice.")
                    .foregroundStyle(LoopColor.text)
            }
            .listRowBackground(LoopColor.surface)

            Section {
                Text("Loop is a new look for NOOP, the open-source WHOOP companion app by ryanbr and its contributors. NOOP does all the strap, storage and scoring work.")
                    .foregroundStyle(LoopColor.text)
                Link("NOOP on GitHub", destination: URL(string: "https://github.com/ryanbr/noop")!)
                LabeledContent("Licence", value: "PolyForm Noncommercial 1.0.0")
                LabeledContent("NOOP version", value: version)
            } header: {
                LoopListHeader("Built on NOOP")
            } footer: {
                Text("Not affiliated with WHOOP. For personal, non-commercial use.")
            }
            .listRowBackground(LoopColor.surface)
        }
        .loopListChrome(title: "About")
    }
}
