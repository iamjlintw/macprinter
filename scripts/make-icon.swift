// 用 CoreGraphics 畫 App 圖示原圖（1024×1024 PNG）：印表機吐出一張照片。
// 用法：swift scripts/make-icon.swift <輸出 PNG 路徑>
// 由 scripts/build-app.sh 呼叫，再用 sips／iconutil 轉成 AppIcon.icns。
import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("用法：swift make-icon.swift <輸出 PNG 路徑>\n".data(using: .utf8)!)
    exit(64)
}
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// 在 path 範圍內由上往下填漸層（座標原點在左下）
func fillGradient(_ path: CGPath, top: CGColor, bottom: CGColor) {
    let box = path.boundingBox
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: box.midX, y: box.maxY),
                           end: CGPoint(x: box.midX, y: box.minY), options: [])
    ctx.restoreGState()
}

func fill(_ path: CGPath, _ color: CGColor) {
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
}

// 底板：macOS 圖示格線的 824×824 圓角方形，四周留 100px
let plate = roundedRect(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.3))
fill(plate, rgb(0x2F6FD6))
ctx.restoreGState()
fillGradient(plate, top: rgb(0x5AA2F0), bottom: rgb(0x2556C0))

// 進紙匣：印表機後方露出的空白紙
fill(roundedRect(CGRect(x: 340, y: 600, width: 344, height: 200), 16), rgb(0xE9EDF2))

// 印表機機身
let body = roundedRect(CGRect(x: 196, y: 330, width: 632, height: 300), 64)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: rgb(0x0A1F4D, 0.45))
fill(body, rgb(0xDDE1E6))
ctx.restoreGState()
fillGradient(body, top: rgb(0xFAFBFC), bottom: rgb(0xC3C9D1))

// 狀態燈
fill(CGPath(ellipseIn: CGRect(x: 716, y: 560, width: 32, height: 32), transform: nil), rgb(0x34C759))

// 出紙口
fill(roundedRect(CGRect(x: 280, y: 438, width: 464, height: 36), 18), rgb(0x3A4250))

// 從出紙口吐出的照片
let paperRect = CGRect(x: 322, y: 168, width: 380, height: 290)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x0A1F4D, 0.35))
fill(CGPath(rect: paperRect, transform: nil), rgb(0xFFFFFF))
ctx.restoreGState()

let photoRect = paperRect.insetBy(dx: 26, dy: 26)
let photo = CGPath(rect: photoRect, transform: nil)
ctx.saveGState()
ctx.addPath(photo)
ctx.clip()
fillGradient(photo, top: rgb(0x8FD3FF), bottom: rgb(0xD9F1FF))
// 太陽
fill(CGPath(ellipseIn: CGRect(x: photoRect.maxX - 112, y: photoRect.maxY - 100, width: 64, height: 64),
            transform: nil), rgb(0xFFC83D))
// 遠山與近山
let far = CGMutablePath()
far.move(to: CGPoint(x: photoRect.minX + 90, y: photoRect.minY))
far.addLine(to: CGPoint(x: photoRect.minX + 220, y: photoRect.minY + 150))
far.addLine(to: CGPoint(x: photoRect.maxX + 40, y: photoRect.minY))
far.closeSubpath()
fill(far, rgb(0x5DBB63))
let near = CGMutablePath()
near.move(to: CGPoint(x: photoRect.minX - 30, y: photoRect.minY))
near.addLine(to: CGPoint(x: photoRect.minX + 100, y: photoRect.minY + 120))
near.addLine(to: CGPoint(x: photoRect.minX + 230, y: photoRect.minY))
near.closeSubpath()
fill(near, rgb(0x2E9A4B))
ctx.restoreGState()

guard let image = ctx.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    exit(1)
}
do {
    try png.write(to: outURL)
} catch {
    FileHandle.standardError.write("寫入失敗：\(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
