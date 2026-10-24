// CUPS 後端：`macprinter:/`
// 呼叫方式（CUPS 規範）：backend job-id user title copies options [file]
// 不帶參數時輸出裝置資訊，供 `lpinfo -v` 列出。
import Foundation
import MacPrinterCore
import os

let logger = Logger(subsystem: MacPrinter.bundleID, category: "backend")

/// stderr 的訊息會顯示在 CUPS 的工作狀態與 error_log；文件標題只記在 os_log 的 private 欄位。
func log(_ level: LogLevel, _ message: String) {
    switch level {
    case .info:
        logger.notice("\(message, privacy: .public)")
        FileHandle.standardError.write(Data("INFO: \(message)\n".utf8))
    case .error:
        logger.error("\(message, privacy: .public)")
        FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    }
}

// CUPS 後端結束代碼
let backendOK: Int32 = 0
let backendFailed: Int32 = 1

let args = CommandLine.arguments
if args.count == 1 {
    print("direct \(MacPrinter.queueName) \"Unknown\" \"\(Strings.backendDeviceInfo)\"")
    exit(backendOK)
}
guard args.count == 6 || args.count == 7 else {
    FileHandle.standardError.write(Data("Usage: \(args[0]) job-id user title copies options [file]\n".utf8))
    exit(backendFailed)
}

let jobID = args[1].filter { $0.isASCII && ($0.isNumber || $0.isLetter || $0 == "-") }
let requestedUser = args[2]
let title = args[3]

// 帳號以系統帳號資料為準，避免路徑字元混進資料夾名稱。
guard !jobID.isEmpty, let passwd = getpwnam(requestedUser) else {
    log(.error, "工作 \(args[1])：找不到送件帳號")
    exit(backendFailed)
}
let user = String(cString: passwd.pointee.pw_name)
guard !user.isEmpty, !user.contains("/"), user != ".", user != ".." else {
    log(.error, "工作 \(jobID)：帳號名稱不合法")
    exit(backendFailed)
}

let pdfData: Data
if args.count == 7 {
    guard let data = FileManager.default.contents(atPath: args[6]) else {
        log(.error, "工作 \(jobID)：無法讀取列印檔")
        exit(backendFailed)
    }
    pdfData = data
} else {
    pdfData = FileHandle.standardInput.readDataToEndOfFile()
}
logger.notice("工作 \(jobID, privacy: .public)：開始，帳號 \(user, privacy: .public)，標題 \(title, privacy: .private)，\(pdfData.count) bytes")

let privileges: PrivilegeScope = getuid() == 0
    ? DroppedUserScope(uid: passwd.pointee.pw_uid, gid: passwd.pointee.pw_gid)
    : CurrentUserScope()
let processor = PrintJobProcessor(privileges: privileges, log: log)

do {
    let manifest = try processor.process(PrintJob(jobID: jobID, user: user, title: title, pdfData: pdfData))
    // 轉檔失敗但已保留 PDF 也算處理完成，不讓佇列停下來。
    exit(manifest.files.isEmpty ? backendFailed : backendOK)
} catch {
    log(.error, "工作 \(jobID)：無法寫入輸出資料夾（\(error)）")
    exit(backendFailed)
}
