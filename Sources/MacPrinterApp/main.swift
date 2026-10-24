// 同一個執行檔兩種模式：
// - 一般啟動：SwiftUI 主視窗
// - `--agent`：由 LaunchAgent 喚起，把列印結果搬到自訂資料夾並發通知，處理完就結束
import Foundation

if CommandLine.arguments.contains(AgentRunner.argument) {
    AgentRunner.runAndExit()
} else {
    MacPrinterApplication.main()
}
