import Foundation

/// 顯示文案集中管理（專案無多語系需求，直接寫繁中）。
public enum Strings {
    public static let appName = "macprinter"
    public static let printerDisplayName = "存成圖片"
    public static let untitled = "未命名"

    // MARK: 通知
    public static let notifySucceededTitle = "已存成圖片"
    public static func notifySucceededBody(title: String, pages: Int, folder: String) -> String {
        "「\(title)」共 \(pages) 頁，已存到「\(folder)」。"
    }
    public static let notifyFailedTitle = "轉檔失敗"
    public static func notifyFailedBody(title: String, folder: String) -> String {
        "「\(title)」無法轉成圖片，原始 PDF 已保留在「\(folder)」。"
    }
    public static func notifyFallbackSuffix(folder: String) -> String {
        "無法存到自訂資料夾，已改存到預設資料夾「\(folder)」。"
    }

    // MARK: App 主視窗
    public static let sectionPrinter = "印表機"
    public static let sectionOutput = "輸出資料夾"
    public static let sectionLog = "記錄"
    public static let statusInstalled = "已安裝"
    public static let statusNotInstalled = "尚未安裝"
    public static let statusPartiallyInstalled = "安裝不完整，請重新安裝"
    public static let agentRunning = "背景程式已啟用"
    public static let agentNotRunning = "背景程式未啟用（重新登入或重新安裝後啟用）"
    public static let printerSummary = "PNG・300 dpi・彩色・白底・每頁一張；預設紙張 A4"
    public static let buttonInstall = "安裝印表機"
    public static let buttonReinstall = "重新安裝"
    public static let buttonUninstall = "移除印表機"
    public static let buttonRefresh = "重新整理"
    public static let buttonChooseFolder = "變更…"
    public static let buttonResetFolder = "恢復預設"
    public static let buttonOpenFolder = "打開資料夾"
    public static let buttonShowLog = "查看記錄"
    public static let buttonClose = "關閉"
    public static let buttonOK = "好"
    public static let outputDefaultHint = "預設資料夾"
    public static let outputCustomHint = "自訂資料夾：列印完成後由背景程式搬過來"
    public static let chooseFolderPrompt = "選擇"
    public static let chooseFolderMessage = "選擇列印圖片要存放的資料夾"
    public static let folderNotCreatedYet = "資料夾還沒建立：安裝印表機或第一次列印後才會出現。"
    public static let folderNotWritable = "這個資料夾無法寫入，請選擇其他資料夾。"
    public static let installPrompt = "macprinter 要安裝或移除「存成圖片」印表機。"
    public static let installSucceeded = "已安裝「存成圖片」印表機。"
    public static let uninstallSucceeded = "已移除「存成圖片」印表機。已產生的圖片仍保留在原資料夾。"
    public static let operationCancelled = "已取消。"
    public static func operationFailed(_ detail: String) -> String { "操作失敗：\(detail)" }
    public static let logEmpty = "最近 24 小時沒有記錄。"
    public static let logTitle = "最近 24 小時的記錄"

    // MARK: 後端（顯示在 CUPS 工作狀態）
    public static let backendDeviceInfo = "macprinter（存成圖片）"
}
