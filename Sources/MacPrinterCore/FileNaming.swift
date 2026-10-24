import Foundation

/// 檔名規則：`<文件標題>_<yyyyMMdd-HHmmss>_p<頁碼>.png`，同名時在時間戳記後加 `-2`、`-3`…。
public enum FileNaming {
    public static let maxTitleLength = 80

    /// 檔名不能用的字元（`/`、`:`、控制字元）換成 `_`；開頭的 `.` 也換掉以免變成隱藏檔。
    public static func sanitizeTitle(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            if scalar == "/" || scalar == ":" || CharacterSet.controlCharacters.contains(scalar) {
                scalars.append("_")
            } else {
                scalars.append(scalar)
            }
        }
        var title = String(scalars).trimmingCharacters(in: .whitespaces)
        if title.hasPrefix(".") {
            title = "_" + title.dropFirst()
        }
        if title.count > maxTitleLength {
            title = String(title.prefix(maxTitleLength)).trimmingCharacters(in: .whitespaces)
        }
        return title.isEmpty ? Strings.untitled : title
    }

    public static func timestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    /// 頁碼依總頁數補零，最少兩位。
    public static func pageDigits(total: Int) -> Int {
        max(2, String(max(total, 1)).count)
    }

    public static func pageFileName(stem: String, page: Int, total: Int) -> String {
        let digits = pageDigits(total: total)
        let number = String(page)
        let padded = String(repeating: "0", count: max(0, digits - number.count)) + number
        return "\(stem)_p\(padded).png"
    }

    public static func failedPDFName(stem: String) -> String {
        "\(stem).pdf"
    }

    /// 依序嘗試 `base`、`base-2`、`base-3`…，直到所有要產生的檔名在資料夾裡都不存在。
    public static func uniqueStem(base: String, fileNames: (String) -> [String], in dir: URL,
                                  fileManager: FileManager = .default) -> String {
        var candidate = base
        var counter = 1
        while fileNames(candidate).contains(where: { fileManager.fileExists(atPath: dir.appendingPathComponent($0).path) }) {
            counter += 1
            candidate = "\(base)-\(counter)"
        }
        return candidate
    }

    /// 一個工作會產生的所有檔名（各頁 PNG＋失敗時保留的 PDF），用來檢查同名。
    public static func jobFileNames(stem: String, pageCount: Int) -> [String] {
        (1...max(pageCount, 1)).map { pageFileName(stem: stem, page: $0, total: pageCount) } + [failedPDFName(stem: stem)]
    }
}
