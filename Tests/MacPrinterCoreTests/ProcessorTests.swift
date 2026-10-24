import XCTest
import ImageIO
@testable import MacPrinterCore

final class ProcessorTests: XCTestCase {
    var root: URL!
    var spool: Spool!
    let user = "tester"

    override func setUp() {
        root = makeTempDir().appendingPathComponent("spool", isDirectory: true)
        spool = Spool(root: root)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    private func process(_ data: Data, title: String = "報表", jobID: String = "1") throws -> JobManifest {
        try PrintJobProcessor(spool: spool, privileges: CurrentUserScope())
            .process(PrintJob(jobID: jobID, user: user, title: title, pdfData: data, createdAt: Date(timeIntervalSince1970: 1_792_809_720)))
    }

    func testMultiPageJobProducesOnePNGPerPage() throws {
        let manifest = try process(TestPDF.make(pages: [TestPDF.a4, TestPDF.a4, TestPDF.letter]))
        XCTAssertEqual(manifest.status, .succeeded)
        XCTAssertEqual(manifest.pageCount, 3)
        XCTAssertEqual(manifest.files.count, 3)
        XCTAssertTrue(manifest.files[0].hasSuffix("_p01.png"))

        let first = spool.userDir(user).appendingPathComponent(manifest.files[0])
        let props = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithURL(first as CFURL, nil)!, 0, nil) as! [CFString: Any]
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 2480)
        XCTAssertEqual(props[kCGImagePropertyDPIWidth] as? Double, 300)

        let inbox = try FileManager.default.contentsOfDirectory(atPath: spool.inboxDir(user).path)
        XCTAssertEqual(inbox, ["job-1.json"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spool.triggerURL.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: spool.userDir(user).path).contains { $0.hasSuffix(".tmp") })
    }

    func testSameNameGetsSequence() throws {
        let a = try process(TestPDF.make(pages: [TestPDF.a4]), jobID: "1")
        let b = try process(TestPDF.make(pages: [TestPDF.a4]), jobID: "2")
        XCTAssertNotEqual(a.stem, b.stem)
        XCTAssertEqual(b.stem, a.stem + "-2")
    }

    func testInvalidPDFKeepsOriginal() throws {
        let manifest = try process(Data("broken".utf8))
        XCTAssertEqual(manifest.status, .failed)
        XCTAssertEqual(manifest.files, [manifest.stem + ".pdf"])
        let kept = try Data(contentsOf: spool.userDir(user).appendingPathComponent(manifest.files[0]))
        XCTAssertEqual(kept, Data("broken".utf8))
    }

    func testInboxLeavesFilesWhenNoCustomFolder() throws {
        let manifest = try process(TestPDF.make(pages: [TestPDF.a4]))
        let results = InboxProcessor(spool: spool, user: user, destination: nil).processAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].folder, spool.userDir(user))
        XCTAssertFalse(results[0].fellBack)
        XCTAssertTrue(FileManager.default.fileExists(atPath: spool.userDir(user).appendingPathComponent(manifest.files[0]).path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: spool.inboxDir(user).path).isEmpty)
    }

    func testInboxMovesToCustomFolderWithDedup() throws {
        let destination = root.deletingLastPathComponent().appendingPathComponent("自訂", isDirectory: true)
        let manifest = try process(TestPDF.make(pages: [TestPDF.a4, TestPDF.a4]))
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data().write(to: destination.appendingPathComponent(manifest.files[1]))

        let results = InboxProcessor(spool: spool, user: user, destination: destination).processAll()
        XCTAssertEqual(results[0].folder, destination)
        XCTAssertEqual(results[0].files.map(\.lastPathComponent), manifest.files.map { $0.replacingOccurrences(of: manifest.stem, with: manifest.stem + "-2") })
        for file in results[0].files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: spool.userDir(user).appendingPathComponent(manifest.files[0]).path))
    }

    func testInboxFallsBackWhenFolderNotWritable() throws {
        let destination = root.deletingLastPathComponent().appendingPathComponent("唯讀", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        chmod(destination.path, 0o500)
        defer { chmod(destination.path, 0o700) }
        let manifest = try process(TestPDF.make(pages: [TestPDF.a4]))

        let results = InboxProcessor(spool: spool, user: user, destination: destination).processAll()
        XCTAssertTrue(results[0].fellBack)
        XCTAssertEqual(results[0].folder, spool.userDir(user))
        XCTAssertTrue(FileManager.default.fileExists(atPath: spool.userDir(user).appendingPathComponent(manifest.files[0]).path))
    }
}
