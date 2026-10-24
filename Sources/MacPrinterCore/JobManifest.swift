import Foundation

/// 後端完成一個列印工作後留給背景程式的清單，放在 `<帳號>/.inbox/<工作編號>.json`。
public struct JobManifest: Codable, Equatable {
    public enum Status: String, Codable {
        case succeeded
        case failed
    }

    public var jobID: String
    public var title: String
    public var stem: String
    public var createdAt: Date
    public var status: Status
    public var pageCount: Int
    /// 檔名（不含路徑），都在 `<帳號>/` 資料夾內。
    public var files: [String]

    public init(jobID: String, title: String, stem: String, createdAt: Date, status: Status, pageCount: Int, files: [String]) {
        self.jobID = jobID
        self.title = title
        self.stem = stem
        self.createdAt = createdAt
        self.status = status
        self.pageCount = pageCount
        self.files = files
    }

    public static func fileName(jobID: String) -> String {
        "job-\(jobID).json"
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> JobManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(JobManifest.self, from: data)
    }
}
