import XCTest
@testable import MacPrinterCore

final class FileNamingTests: XCTestCase {
    func testSanitizeReplacesIllegalCharacters() {
        XCTAssertEqual(FileNaming.sanitizeTitle("報表/2026:10"), "報表_2026_10")
        XCTAssertEqual(FileNaming.sanitizeTitle("a\nb\tc"), "a_b_c")
    }

    func testSanitizeEmptyBecomesUntitled() {
        XCTAssertEqual(FileNaming.sanitizeTitle(""), "未命名")
        XCTAssertEqual(FileNaming.sanitizeTitle("   "), "未命名")
    }

    func testSanitizeLeadingDotAndLength() {
        XCTAssertEqual(FileNaming.sanitizeTitle(".hidden"), "_hidden")
        XCTAssertEqual(FileNaming.sanitizeTitle(String(repeating: "字", count: 200)).count, FileNaming.maxTitleLength)
    }

    func testTimestampFormat() {
        let date = Date(timeIntervalSince1970: 1_792_809_720) // 2026-10-24 02:42:00 UTC
        XCTAssertEqual(FileNaming.timestamp(date, timeZone: TimeZone(identifier: "Asia/Taipei")!), "20261024-104200")
    }

    func testPageDigits() {
        XCTAssertEqual(FileNaming.pageFileName(stem: "s", page: 1, total: 1), "s_p01.png")
        XCTAssertEqual(FileNaming.pageFileName(stem: "s", page: 7, total: 99), "s_p07.png")
        XCTAssertEqual(FileNaming.pageFileName(stem: "s", page: 7, total: 100), "s_p007.png")
    }

    func testUniqueStemAddsSequence() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let names = { FileNaming.jobFileNames(stem: $0, pageCount: 2) }
        XCTAssertEqual(FileNaming.uniqueStem(base: "a", fileNames: names, in: dir), "a")
        try Data().write(to: dir.appendingPathComponent("a_p02.png"))
        XCTAssertEqual(FileNaming.uniqueStem(base: "a", fileNames: names, in: dir), "a-2")
        try Data().write(to: dir.appendingPathComponent("a-2.pdf"))
        XCTAssertEqual(FileNaming.uniqueStem(base: "a", fileNames: names, in: dir), "a-3")
    }
}
