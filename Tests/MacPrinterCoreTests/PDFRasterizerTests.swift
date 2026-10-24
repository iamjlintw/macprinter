import XCTest
@testable import MacPrinterCore

final class PDFRasterizerTests: XCTestCase {
    func testA4At300dpi() throws {
        let document = try PDFRasterizer.open(TestPDF.make(pages: [TestPDF.a4]))
        let image = try PDFRasterizer.render(document.page(at: 1)!, pageNumber: 1, dpi: 300)
        XCTAssertEqual(image.width, 2480)
        XCTAssertEqual(image.height, 3508)
    }

    func testRotatedPageSwapsSize() throws {
        let document = try PDFRasterizer.open(TestPDF.make(pages: [TestPDF.letter], rotation: 90))
        let image = try PDFRasterizer.render(document.page(at: 1)!, pageNumber: 1, dpi: 300)
        XCTAssertEqual(image.width, 3300)
        XCTAssertEqual(image.height, 2550)
        // 左下角的方塊轉 90° 後應出現在左上角（點陣圖第一列在最上方）
        XCTAssertEqual(pixel(image, x: 10, y: 10), 0)
        XCTAssertEqual(pixel(image, x: 10, y: image.height - 10), 255)
    }

    func testBackgroundIsWhite() throws {
        let document = try PDFRasterizer.open(TestPDF.make(pages: [TestPDF.letter]))
        let image = try PDFRasterizer.render(document.page(at: 1)!, pageNumber: 1, dpi: 300)
        XCTAssertEqual(pixel(image, x: image.width - 5, y: 5), 255)
        XCTAssertEqual(pixel(image, x: 5, y: image.height - 5), 0)
    }

    func testInvalidPDF() {
        XCTAssertThrowsError(try PDFRasterizer.open(Data("not a pdf".utf8))) {
            XCTAssertEqual($0 as? PDFRasterizer.Failure, .invalidPDF)
        }
    }

    /// 取 (x, y) 的紅色值；y 以點陣圖最上方為 0。
    private func pixel(_ image: CGImage, x: Int, y: Int) -> UInt8 {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return context.data!.load(as: UInt8.self)
    }
}
