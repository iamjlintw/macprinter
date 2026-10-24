import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// 用 macOS 內建的 CoreGraphics 把 PDF 頁面轉成白底 RGB 點陣圖。
public enum PDFRasterizer {
    public enum Failure: Error, Equatable {
        case invalidPDF
        case emptyDocument
        case renderFailed(page: Int)
        case writeFailed(page: Int)
    }

    public static func open(_ data: Data) throws -> CGPDFDocument {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else {
            throw Failure.invalidPDF
        }
        guard document.numberOfPages > 0 else { throw Failure.emptyDocument }
        return document
    }

    /// 輸出的像素尺寸：以 CropBox（PDF 檢視器實際顯示的範圍）為準，並套用頁面的旋轉角度。
    public static func pixelSize(of page: CGPDFPage, dpi: CGFloat) -> (width: Int, height: Int) {
        let box = page.getBoxRect(.cropBox)
        let scale = dpi / 72
        let width = Int((box.width * scale).rounded())
        let height = Int((box.height * scale).rounded())
        return isQuarterTurn(page) ? (height, width) : (width, height)
    }

    public static func render(_ page: CGPDFPage, pageNumber: Int, dpi: CGFloat) throws -> CGImage {
        let box = page.getBoxRect(.cropBox)
        let scale = dpi / 72
        let (width, height) = pixelSize(of: page, dpi: dpi)
        guard width > 0, height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw Failure.renderFailed(page: pageNumber)
        }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.setShouldAntialias(true)

        let w = CGFloat(width), h = CGFloat(height)
        switch normalizedRotation(page) {
        case 90:
            context.translateBy(x: 0, y: h)
            context.rotate(by: -.pi / 2)
        case 180:
            context.translateBy(x: w, y: h)
            context.rotate(by: .pi)
        case 270:
            context.translateBy(x: w, y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.clip(to: box)
        context.drawPDFPage(page)

        guard let image = context.makeImage() else { throw Failure.renderFailed(page: pageNumber) }
        return image
    }

    /// 先寫到同資料夾的暫存檔再改名，避免背景程式讀到寫一半的檔案。
    public static func writePNG(_ image: CGImage, to url: URL, dpi: CGFloat, pageNumber: Int) throws {
        let temp = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        guard let destination = CGImageDestinationCreateWithURL(temp as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.writeFailed(page: pageNumber)
        }
        let properties: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temp)
            throw Failure.writeFailed(page: pageNumber)
        }
        do {
            try FileManager.default.moveItem(at: temp, to: url)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw Failure.writeFailed(page: pageNumber)
        }
    }

    private static func normalizedRotation(_ page: CGPDFPage) -> Int32 {
        ((page.rotationAngle % 360) + 360) % 360
    }

    private static func isQuarterTurn(_ page: CGPDFPage) -> Bool {
        let angle = normalizedRotation(page)
        return angle == 90 || angle == 270
    }
}
