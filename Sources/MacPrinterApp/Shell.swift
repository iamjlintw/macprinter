import Foundation

enum Shell {
    struct Output {
        var status: Int32
        var stdout: String
    }

    /// 執行外部指令並等它結束；不經過 shell，參數不會被解讀。
    static func run(_ path: String, _ arguments: [String]) -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return Output(status: -1, stdout: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(status: process.terminationStatus, stdout: String(decoding: data, as: UTF8.self))
    }

    /// 單引號包住，給 `do shell script` 用。
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
