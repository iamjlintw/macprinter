import AppKit
import MacPrinterCore

@MainActor
final class AppModel: ObservableObject {
    @Published var status = PrinterInstaller.Status(printerRegistered: false, backendInstalled: false, agentInstalled: false, agentLoaded: false)
    @Published var outputFolder = Settings.effectiveOutputFolder
    @Published var isCustomFolder = Settings.customOutputFolder != nil
    @Published var message: String?
    @Published var isBusy = false
    @Published var logText: String?

    func refresh() {
        status = PrinterInstaller.currentStatus()
        outputFolder = Settings.effectiveOutputFolder
        isCustomFolder = Settings.customOutputFolder != nil
    }

    func install() {
        perform(PrinterInstaller.install, success: Strings.installSucceeded)
    }

    func uninstall() {
        perform(PrinterInstaller.uninstall, success: Strings.uninstallSucceeded)
    }

    private func perform(_ action: () -> PrinterInstaller.Outcome, success: String) {
        isBusy = true
        defer { isBusy = false }
        switch action() {
        case .succeeded: message = success
        case .cancelled: message = Strings.operationCancelled
        case .failed(let detail): message = Strings.operationFailed(detail)
        }
        refresh()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = Strings.chooseFolderPrompt
        panel.message = Strings.chooseFolderMessage
        panel.directoryURL = outputFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard FileManager.default.isWritableFile(atPath: url.path) else {
            message = Strings.folderNotWritable
            return
        }
        Settings.customOutputFolder = url
        refresh()
    }

    func resetFolder() {
        Settings.customOutputFolder = nil
        refresh()
    }

    func openFolder() {
        if FileManager.default.fileExists(atPath: outputFolder.path) {
            NSWorkspace.shared.open(outputFolder)
        } else {
            message = Strings.folderNotCreatedYet
        }
    }

    func loadLog() {
        Task.detached {
            let output = Shell.run("/usr/bin/log", ["show", "--last", "24h", "--style", "compact", "--info",
                                                    "--predicate", "subsystem == \"\(MacPrinter.bundleID)\""])
            // 第一行是欄位標題
            let lines = output.stdout.split(separator: "\n").dropFirst()
            let text = lines.isEmpty ? Strings.logEmpty : lines.joined(separator: "\n")
            await MainActor.run { self.logText = text }
        }
    }
}
