import Foundation
import MacPrinterCore
import os

/// LaunchAgent 模式：處理 `.inbox` 裡的工作後結束。
enum AgentRunner {
    static let argument = "--agent"
    private static let logger = Logger(subsystem: MacPrinter.bundleID, category: "agent")

    static func runAndExit() -> Never {
        Task {
            let processor = InboxProcessor(destination: Settings.customOutputFolder) { level, message in
                switch level {
                case .info: logger.notice("\(message, privacy: .public)")
                case .error: logger.error("\(message, privacy: .public)")
                }
            }
            let results = processor.processAll()
            if !results.isEmpty {
                logger.notice("處理 \(results.count, privacy: .public) 個工作")
                await Notifier.requestAuthorizationIfNeeded(timeout: 60)
                for result in results {
                    await Notifier.post(result)
                }
            }
            exit(0)
        }
        dispatchMain()
    }
}
