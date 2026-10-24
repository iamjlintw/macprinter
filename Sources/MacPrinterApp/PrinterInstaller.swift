import AppKit
import MacPrinterCore
import os

/// 以系統管理員密碼對話框執行 App 內附的安裝／移除腳本（`Contents/Resources/*.sh`）。
enum PrinterInstaller {
    private static let logger = Logger(subsystem: MacPrinter.bundleID, category: "installer")

    enum Outcome {
        case succeeded
        case cancelled
        case failed(String)
    }

    struct Status {
        var printerRegistered: Bool
        var backendInstalled: Bool
        var agentInstalled: Bool
        var agentLoaded: Bool

        var isInstalled: Bool { printerRegistered && backendInstalled && agentInstalled }
        var isPartiallyInstalled: Bool { !isInstalled && (printerRegistered || backendInstalled || agentInstalled) }
    }

    static func currentStatus() -> Status {
        let fileManager = FileManager.default
        return Status(
            printerRegistered: Shell.run("/usr/bin/lpstat", ["-p", MacPrinter.queueName]).status == 0,
            backendInstalled: fileManager.fileExists(atPath: MacPrinter.backendPath),
            agentInstalled: fileManager.fileExists(atPath: MacPrinter.agentPlistPath),
            agentLoaded: Shell.run("/bin/launchctl", ["print", "gui/\(getuid())/\(MacPrinter.agentLabel)"]).status == 0
        )
    }

    static var scriptsAvailable: Bool { script("install") != nil && script("uninstall") != nil }

    static func install() -> Outcome {
        guard let script = script("install") else { return .failed("找不到安裝腳本") }
        return runAsAdmin([script.path, Bundle.main.bundlePath, String(getuid())])
    }

    static func uninstall() -> Outcome {
        guard let script = script("uninstall") else { return .failed("找不到移除腳本") }
        return runAsAdmin([script.path])
    }

    private static func script(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "sh")
    }

    private static func runAsAdmin(_ arguments: [String]) -> Outcome {
        let command = (["/bin/bash"] + arguments).map(Shell.quote).joined(separator: " ")
        let source = "do shell script \"\(escape(command))\" with prompt \"\(escape(Strings.installPrompt))\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return .succeeded }
        let number = error[NSAppleScript.errorNumber] as? Int
        if number == -128 { return .cancelled }
        let detail = error[NSAppleScript.errorMessage] as? String ?? "未知錯誤"
        logger.error("管理員腳本失敗（代碼 \(number ?? 0, privacy: .public)）：\(detail, privacy: .public)")
        return .failed("\(detail)（代碼 \(number.map(String.init) ?? "?")）")
    }

    /// AppleScript 字串常值的跳脫。
    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
