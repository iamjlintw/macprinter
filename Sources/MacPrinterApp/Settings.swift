import Foundation
import MacPrinterCore

/// 各帳號自己的設定（存在該帳號的 UserDefaults，背景程式與主視窗是同一個 bundle，讀得到同一份）。
enum Settings {
    private static let outputFolderKey = "outputFolderPath"

    /// nil 表示使用預設資料夾。
    static var customOutputFolder: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: outputFolderKey), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: outputFolderKey)
        }
    }

    static var defaultOutputFolder: URL {
        Spool().userDir(NSUserName())
    }

    static var effectiveOutputFolder: URL {
        customOutputFolder ?? defaultOutputFolder
    }
}
