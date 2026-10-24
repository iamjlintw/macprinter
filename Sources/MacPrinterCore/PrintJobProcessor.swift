import Foundation
import CoreGraphics

public struct PrintJob {
    public var jobID: String
    public var user: String
    public var title: String
    public var pdfData: Data
    public var createdAt: Date

    public init(jobID: String, user: String, title: String, pdfData: Data, createdAt: Date = Date()) {
        self.jobID = jobID
        self.user = user
        self.title = title
        self.pdfData = pdfData
        self.createdAt = createdAt
    }
}

public enum LogLevel {
    case info
    case error
}

/// 後端的處理流程：PDF → 每頁一張 PNG；失敗時保留原始 PDF。最後寫 manifest 並更新 trigger 喚起背景程式。
public struct PrintJobProcessor {
    public let spool: Spool
    public let dpi: CGFloat
    public let privileges: PrivilegeScope
    public let log: (LogLevel, String) -> Void
    private let fileManager = FileManager.default

    public init(spool: Spool = Spool(), dpi: CGFloat = MacPrinter.dpi, privileges: PrivilegeScope,
                log: @escaping (LogLevel, String) -> Void = { _, _ in }) {
        self.spool = spool
        self.dpi = dpi
        self.privileges = privileges
        self.log = log
    }

    /// 只有資料夾或 manifest 寫不進去時才丟錯；轉檔失敗會以 `.failed` 的 manifest 回傳。
    @discardableResult
    public func process(_ job: PrintJob) throws -> JobManifest {
        try prepareDirectories(user: job.user)
        let manifest = try privileges.asUser { () throws -> JobManifest in
            let manifest = convert(job)
            try writeManifest(manifest, user: job.user)
            return manifest
        }
        touchTrigger()
        return manifest
    }

    // MARK: - 資料夾

    private func prepareDirectories(user: String) throws {
        try ensureDirectory(spool.root, mode: 0o711, owner: privileges.owner == nil ? nil : (0, 0))
        try ensureDirectory(spool.userDir(user), mode: 0o700, owner: privileges.owner)
        try privileges.asUser {
            try ensureDirectory(spool.inboxDir(user), mode: 0o700, owner: nil)
        }
    }

    private func ensureDirectory(_ url: URL, mode: mode_t, owner: (uid: uid_t, gid: gid_t)?) throws {
        var info = stat()
        if lstat(url.path, &info) == 0 {
            guard (info.st_mode & S_IFMT) == S_IFDIR else {
                throw PrivilegeError(description: "\(url.path) 不是資料夾")
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        }
        if let owner, chown(url.path, owner.uid, owner.gid) != 0 {
            throw PrivilegeError(description: "chown \(url.path) 失敗：\(String(cString: strerror(errno)))")
        }
        chmod(url.path, mode)
    }

    // MARK: - 轉檔

    private func convert(_ job: PrintJob) -> JobManifest {
        let userDir = spool.userDir(job.user)
        let base = "\(FileNaming.sanitizeTitle(job.title))_\(FileNaming.timestamp(job.createdAt))"

        let document: CGPDFDocument
        do {
            document = try PDFRasterizer.open(job.pdfData)
        } catch {
            log(.error, "工作 \(job.jobID)：無法解析 PDF（\(error)）")
            return keepOriginalPDF(job, base: base, pageCount: 0, in: userDir)
        }

        let pageCount = document.numberOfPages
        let stem = FileNaming.uniqueStem(base: base, fileNames: { FileNaming.jobFileNames(stem: $0, pageCount: pageCount) }, in: userDir)
        var written: [String] = []
        do {
            for number in 1...pageCount {
                guard let page = document.page(at: number) else { throw PDFRasterizer.Failure.renderFailed(page: number) }
                let image = try PDFRasterizer.render(page, pageNumber: number, dpi: dpi)
                let name = FileNaming.pageFileName(stem: stem, page: number, total: pageCount)
                try PDFRasterizer.writePNG(image, to: userDir.appendingPathComponent(name), dpi: dpi, pageNumber: number)
                chmod(userDir.appendingPathComponent(name).path, 0o644)
                written.append(name)
            }
        } catch {
            log(.error, "工作 \(job.jobID)：轉檔失敗（\(error)），改為保留原始 PDF")
            for name in written {
                try? fileManager.removeItem(at: userDir.appendingPathComponent(name))
            }
            return keepOriginalPDF(job, base: base, pageCount: pageCount, in: userDir)
        }

        log(.info, "工作 \(job.jobID)：完成，共 \(pageCount) 頁")
        return JobManifest(jobID: job.jobID, title: FileNaming.sanitizeTitle(job.title), stem: stem, createdAt: job.createdAt,
                           status: .succeeded, pageCount: pageCount, files: written)
    }

    private func keepOriginalPDF(_ job: PrintJob, base: String, pageCount: Int, in userDir: URL) -> JobManifest {
        let stem = FileNaming.uniqueStem(base: base, fileNames: { FileNaming.jobFileNames(stem: $0, pageCount: pageCount) }, in: userDir)
        let name = FileNaming.failedPDFName(stem: stem)
        var files: [String] = []
        do {
            try job.pdfData.write(to: userDir.appendingPathComponent(name), options: .atomic)
            chmod(userDir.appendingPathComponent(name).path, 0o644)
            files = [name]
        } catch {
            log(.error, "工作 \(job.jobID)：連原始 PDF 都無法保留（\(error)）")
        }
        return JobManifest(jobID: job.jobID, title: FileNaming.sanitizeTitle(job.title), stem: stem, createdAt: job.createdAt,
                           status: .failed, pageCount: pageCount, files: files)
    }

    // MARK: - 交接給背景程式

    private func writeManifest(_ manifest: JobManifest, user: String) throws {
        let url = spool.inboxDir(user).appendingPathComponent(JobManifest.fileName(jobID: manifest.jobID))
        try manifest.encoded().write(to: url, options: .atomic)
    }

    /// 各帳號的 LaunchAgent 以 WatchPaths 監看這個檔案。
    private func touchTrigger() {
        let url = spool.triggerURL
        do {
            try Data(ISO8601DateFormatter().string(from: Date()).utf8).write(to: url, options: .atomic)
            chmod(url.path, 0o644)
        } catch {
            log(.error, "無法更新 trigger（\(error)），背景程式要等下次登入才會處理")
        }
    }
}
