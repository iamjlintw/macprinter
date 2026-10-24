import Foundation

/// 背景程式的處理流程：讀 manifest，把圖片搬到使用者設定的資料夾，回傳結果讓呼叫端發通知。
public struct InboxProcessor {
    public struct Result {
        public var manifest: JobManifest
        /// 檔案最後所在的資料夾。
        public var folder: URL
        /// 自訂資料夾寫不進去，改留在預設資料夾。
        public var fellBack: Bool
        public var files: [URL]
    }

    public let spool: Spool
    public let user: String
    /// nil 表示沒有自訂，留在預設資料夾。
    public let destination: URL?
    public let log: (LogLevel, String) -> Void
    private let fileManager = FileManager.default

    public init(spool: Spool = Spool(), user: String = NSUserName(), destination: URL?,
                log: @escaping (LogLevel, String) -> Void = { _, _ in }) {
        self.spool = spool
        self.user = user
        self.destination = destination
        self.log = log
    }

    public func pendingManifests() -> [(url: URL, manifest: JobManifest)] {
        let inbox = spool.inboxDir(user)
        guard let urls = try? fileManager.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else { return [] }
        var items: [(URL, JobManifest)] = []
        for url in urls where url.pathExtension == "json" {
            do {
                items.append((url, try JobManifest.decode(Data(contentsOf: url))))
            } catch {
                log(.error, "manifest 無法讀取，已略過並刪除：\(url.lastPathComponent)（\(error)）")
                try? fileManager.removeItem(at: url)
            }
        }
        return items.sorted { $0.1.createdAt < $1.1.createdAt }
    }

    public func processAll() -> [Result] {
        pendingManifests().map { item in
            let result = deliver(item.manifest)
            try? fileManager.removeItem(at: item.url)
            return result
        }
    }

    private func deliver(_ manifest: JobManifest) -> Result {
        let source = spool.userDir(user)
        let sourceFiles = manifest.files.map { source.appendingPathComponent($0) }
        guard let destination, destination.standardizedFileURL != source.standardizedFileURL else {
            return Result(manifest: manifest, folder: source, fellBack: false, files: sourceFiles)
        }

        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            guard fileManager.isWritableFile(atPath: destination.path) else {
                throw CocoaError(.fileWriteNoPermission)
            }
        } catch {
            log(.error, "工作 \(manifest.jobID)：自訂資料夾無法使用（\(error)），留在預設資料夾")
            return Result(manifest: manifest, folder: source, fellBack: true, files: sourceFiles)
        }

        // 到了目的地再檢查一次同名，必要時換成 -2、-3…
        let renamed = { (stem: String) in manifest.files.map { stem + $0.dropFirst(manifest.stem.count) } }
        let stem = FileNaming.uniqueStem(base: manifest.stem, fileNames: renamed, in: destination)
        let targets = renamed(stem).map { destination.appendingPathComponent($0) }

        var moved: [(from: URL, to: URL)] = []
        for (from, to) in zip(sourceFiles, targets) {
            do {
                try fileManager.moveItem(at: from, to: to)
                moved.append((from, to))
            } catch {
                log(.error, "工作 \(manifest.jobID)：搬檔失敗（\(error)），全部留在預設資料夾")
                for pair in moved.reversed() {
                    try? fileManager.moveItem(at: pair.to, to: pair.from)
                }
                return Result(manifest: manifest, folder: source, fellBack: true, files: sourceFiles)
            }
        }
        log(.info, "工作 \(manifest.jobID)：已搬到自訂資料夾，共 \(targets.count) 個檔案")
        return Result(manifest: manifest, folder: destination, fellBack: false, files: targets)
    }
}
