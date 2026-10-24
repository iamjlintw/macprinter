import Foundation
import CoreGraphics

/// 全專案共用的常數。安裝腳本 `Packaging/install.sh` 內有同樣的值，修改時要一起改。
public enum MacPrinter {
    public static let bundleID = "io.github.iamjlintw.macprinter"
    public static let agentLabel = "io.github.iamjlintw.macprinter.agent"
    /// CUPS 佇列名稱（只能用 ASCII）；顯示名稱見 `Strings.printerDisplayName`。
    public static let queueName = "macprinter"
    public static let backendPath = "/usr/libexec/cups/backend/macprinter"
    public static let agentPlistPath = "/Library/LaunchAgents/\(agentLabel).plist"
    public static let dpi: CGFloat = 300

    public static let defaultSpoolRoot = "/Users/Shared/macprinter"
    public static let triggerFileName = ".trigger"
    public static let inboxDirName = ".inbox"
    /// 只在非 root 執行（測試）時採用，避免以 root 執行的後端被導向其他位置。
    public static let spoolRootEnvKey = "MACPRINTER_SPOOL_ROOT"

    public static var spoolRoot: URL {
        if getuid() != 0, let path = ProcessInfo.processInfo.environment[spoolRootEnvKey], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: defaultSpoolRoot, isDirectory: true)
    }
}

/// 輸出資料夾的路徑規則。
public struct Spool {
    public let root: URL

    public init(root: URL = MacPrinter.spoolRoot) {
        self.root = root
    }

    public var triggerURL: URL { root.appendingPathComponent(MacPrinter.triggerFileName) }

    public func userDir(_ user: String) -> URL {
        root.appendingPathComponent(user, isDirectory: true)
    }

    public func inboxDir(_ user: String) -> URL {
        userDir(user).appendingPathComponent(MacPrinter.inboxDirName, isDirectory: true)
    }
}
