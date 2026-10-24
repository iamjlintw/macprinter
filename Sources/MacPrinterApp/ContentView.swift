import SwiftUI
import MacPrinterCore

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        Form {
            Section(Strings.sectionPrinter) {
                LabeledContent(Strings.printerDisplayName) {
                    Text(statusText)
                        .foregroundStyle(model.status.isInstalled ? .primary : .secondary)
                }
                if model.status.isInstalled {
                    Text(model.status.agentLoaded ? Strings.agentRunning : Strings.agentNotRunning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(Strings.printerSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(model.status.isInstalled ? Strings.buttonReinstall : Strings.buttonInstall, action: model.install)
                    Button(Strings.buttonUninstall, role: .destructive, action: model.uninstall)
                        .disabled(!(model.status.isInstalled || model.status.isPartiallyInstalled))
                    Spacer()
                    Button(Strings.buttonRefresh, action: model.refresh)
                }
                .disabled(model.isBusy || !PrinterInstaller.scriptsAvailable)
            }

            Section(Strings.sectionOutput) {
                LabeledContent(model.isCustomFolder ? Strings.outputCustomHint : Strings.outputDefaultHint) {
                    Text(model.outputFolder.path)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack {
                    Button(Strings.buttonChooseFolder, action: model.chooseFolder)
                    Button(Strings.buttonResetFolder, action: model.resetFolder)
                        .disabled(!model.isCustomFolder)
                    Spacer()
                    Button(Strings.buttonOpenFolder, action: model.openFolder)
                }
            }

            Section(Strings.sectionLog) {
                Button(Strings.buttonShowLog, action: model.loadLog)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 460)
        .onAppear(perform: model.refresh)
        .alert(model.message ?? "", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button(Strings.buttonOK, role: .cancel) { model.message = nil }
        }
        .sheet(isPresented: Binding(get: { model.logText != nil }, set: { if !$0 { model.logText = nil } })) {
            LogView(text: model.logText ?? "") { model.logText = nil }
        }
    }

    private var statusText: String {
        if model.status.isInstalled { return Strings.statusInstalled }
        if model.status.isPartiallyInstalled { return Strings.statusPartiallyInstalled }
        return Strings.statusNotInstalled
    }
}

struct LogView: View {
    let text: String
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.logTitle).font(.headline)
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button(Strings.buttonClose, action: close)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 720, height: 420)
    }
}
