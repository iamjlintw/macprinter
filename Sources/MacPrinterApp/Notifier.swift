import AppKit
import MacPrinterCore
import UserNotifications

/// 系統通知；點通知會在 Finder 選取輸出的檔案（由 `AppDelegate` 處理）。
enum Notifier {
    static let filesKey = "files"
    static let folderKey = "folder"

    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() async {
        guard isAvailable else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// 背景程式用：還沒問過才問，最多等 `timeout` 秒，使用者沒回應也不會讓背景程式卡住。
    static func requestAuthorizationIfNeeded(timeout: TimeInterval) async {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = ResumeOnce(continuation)
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in once.resume() }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { once.resume() }
        }
    }

    /// 以 lock 保護，可以安全地跨執行緒使用。
    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?

        init(_ continuation: CheckedContinuation<Void, Never>) {
            self.continuation = continuation
        }

        func resume() {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume()
        }
    }

    static func post(_ result: InboxProcessor.Result) async {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        let folderName = result.folder.lastPathComponent
        switch result.manifest.status {
        case .succeeded:
            content.title = Strings.notifySucceededTitle
            content.body = Strings.notifySucceededBody(title: result.manifest.title, pages: result.manifest.pageCount, folder: folderName)
        case .failed:
            content.title = Strings.notifyFailedTitle
            content.body = Strings.notifyFailedBody(title: result.manifest.title, folder: folderName)
        }
        if result.fellBack {
            content.body += "\n" + Strings.notifyFallbackSuffix(folder: folderName)
        }
        content.userInfo = [folderKey: result.folder.path, filesKey: result.files.map(\.path)]
        let request = UNNotificationRequest(identifier: "job-\(result.manifest.jobID)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func reveal(userInfo: [AnyHashable: Any]) {
        let files = (userInfo[filesKey] as? [String] ?? []).map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        if !files.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(files)
        } else if let folder = userInfo[folderKey] as? String {
            NSWorkspace.shared.open(URL(fileURLWithPath: folder, isDirectory: true))
        }
    }
}
