import Foundation
import CoreGraphics

enum TestPDF {
    /// 產生測試用 PDF；每頁左下角畫一個黑色方塊，方便檢查旋轉方向。
    static func make(pages: [CGSize], rotation: Int32 = 0) -> Data {
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var first = CGRect(origin: .zero, size: pages[0])
        let context = CGContext(consumer: consumer, mediaBox: &first, nil)!
        for size in pages {
            var box = CGRect(origin: .zero, size: size)
            var info: [CFString: Any] = [kCGPDFContextMediaBox: Data(bytes: &box, count: MemoryLayout<CGRect>.size)]
            if rotation != 0 { info["Rotate" as CFString] = rotation }
            context.beginPDFPage(info as CFDictionary)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 72, height: 72))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    static let a4 = CGSize(width: 595.2756, height: 841.8898)
    static let letter = CGSize(width: 612, height: 792)
}

func makeTempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("macprinter-tests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
