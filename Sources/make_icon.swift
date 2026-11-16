import AppKit
import CoreGraphics

func renderIcon(size: Int, to path: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let scale = CGFloat(size) / 1024.0
    ctx.scaleBy(x: scale, y: scale)

    ctx.clear(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // 1. macOS Squircle Background
    let bgRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 185, yRadius: 185)
    ctx.saveGState()
    bgPath.addClip()
    let bgColors = [
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.18, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.27, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Metallic rim on squircle
    NSColor(calibratedRed: 0.45, green: 0.50, blue: 0.60, alpha: 0.55).setStroke()
    bgPath.lineWidth = 14
    bgPath.stroke()

    // 2. Physical Movie Script (slightly rotated, cream paper, stacked pages)
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 512)
    ctx.rotate(by: 0.04) // subtle ~2.3 deg tilt
    ctx.translateBy(x: -512, y: -512)

    // Under-page shadow/stack
    let backPage = NSBezierPath(roundedRect: CGRect(x: 248, y: 192, width: 528, height: 644), xRadius: 12, yRadius: 12)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: NSColor(white: 0.0, alpha: 0.55).cgColor)
    NSColor(calibratedRed: 0.85, green: 0.83, blue: 0.78, alpha: 1.0).setFill()
    backPage.fill()
    ctx.restoreGState()

    // Top script page
    let pageRect = CGRect(x: 236, y: 204, width: 528, height: 644)
    let pagePath = NSBezierPath(roundedRect: pageRect, xRadius: 10, yRadius: 10)
    NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.89, alpha: 1.0).setFill()
    pagePath.fill()

    // Left binding crease line
    NSColor(calibratedRed: 0.80, green: 0.78, blue: 0.73, alpha: 1.0).setStroke()
    let crease = NSBezierPath()
    crease.move(to: CGPoint(x: 312, y: 204))
    crease.line(to: CGPoint(x: 312, y: 848))
    crease.lineWidth = 2
    crease.stroke()

    // 3 Brass Brads on left margin
    for by in [740.0, 526.0, 312.0] {
        let bradRect = CGRect(x: 256, y: by - 22, width: 44, height: 44)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 6, color: NSColor(white: 0.0, alpha: 0.45).cgColor)
        NSBezierPath(ovalIn: bradRect).addClip()
        let bradColors = [
            NSColor(calibratedRed: 0.78, green: 0.64, blue: 0.34, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.42, green: 0.33, blue: 0.14, alpha: 1.0).cgColor
        ] as CFArray
        let bradGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bradColors, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(bradGrad, start: CGPoint(x: 264, y: by + 20), end: CGPoint(x: 292, y: by - 20), options: [])
        ctx.restoreGState()
    }

    // Screenplay Courier Text on Page
    let courierBold = NSFont(name: "Courier-Bold", size: 30) ?? NSFont.monospacedSystemFont(ofSize: 30, weight: .bold)
    let courierReg = NSFont(name: "Courier", size: 20) ?? NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
    let inkColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)

    let slugAttrs: [NSAttributedString.Key: Any] = [.font: courierBold, .foregroundColor: inkColor]
    let bodyAttrs: [NSAttributedString.Key: Any] = [.font: courierReg, .foregroundColor: inkColor]

    ("12   INT. LIVING ROOM - NIGHT" as NSString).draw(at: CGPoint(x: 334, y: 690), withAttributes: slugAttrs)
    ("Hujan deras membasahi jendela." as NSString).draw(at: CGPoint(x: 334, y: 620), withAttributes: bodyAttrs)
    ("Lampu ruang tamu berkedip pelan." as NSString).draw(at: CGPoint(x: 334, y: 588), withAttributes: bodyAttrs)

    ("ADIA" as NSString).draw(at: CGPoint(x: 495, y: 515), withAttributes: slugAttrs)
    ("(berbisik)" as NSString).draw(at: CGPoint(x: 455, y: 480), withAttributes: bodyAttrs)
    ("Kita harus periksa semua" as NSString).draw(at: CGPoint(x: 395, y: 446), withAttributes: bodyAttrs)
    ("adegan sebelum malam ini." as NSString).draw(at: CGPoint(x: 395, y: 416), withAttributes: bodyAttrs)

    ("13   EXT. HALAMAN - CONTINUOUS" as NSString).draw(at: CGPoint(x: 334, y: 340), withAttributes: slugAttrs)
    ("Pintu terbuka dari dalam." as NSString).draw(at: CGPoint(x: 334, y: 295), withAttributes: bodyAttrs)

    ctx.restoreGState() // End page tilt

    // 3. Magnifying Glass overlapping "12  INT."
    let lensCenter = CGPoint(x: 525, y: 605)
    let lensRadius: CGFloat = 178

    // Handle (bottom-right at 45 deg)
    ctx.saveGState()
    ctx.translateBy(x: lensCenter.x, y: lensCenter.y)
    ctx.rotate(by: -0.78) // -45 deg
    // Neck
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: NSColor(white: 0.0, alpha: 0.55).cgColor)
    let neckRect = CGRect(x: lensRadius + 6, y: -16, width: 42, height: 32)
    NSColor(calibratedRed: 0.62, green: 0.66, blue: 0.72, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: neckRect, xRadius: 6, yRadius: 6).fill()
    // Grip
    let gripRect = CGRect(x: lensRadius + 44, y: -26, width: 175, height: 52)
    let gripPath = NSBezierPath(roundedRect: gripRect, xRadius: 24, yRadius: 24)
    let gripColors = [
        NSColor(calibratedRed: 0.25, green: 0.30, blue: 0.38, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.18, alpha: 1.0).cgColor
    ] as CFArray
    let gripGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gripColors, locations: [0.0, 1.0])!
    ctx.saveGState()
    gripPath.addClip()
    ctx.drawLinearGradient(gripGrad, start: CGPoint(x: lensCenter.x, y: 26), end: CGPoint(x: lensCenter.x, y: -26), options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    // Lens Glass Interior (magnified crisp "12 / INT. LIVING")
    let lensRect = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    let lensPath = NSBezierPath(ovalIn: lensRect)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 28, color: NSColor(white: 0.0, alpha: 0.5).cgColor)
    NSColor(calibratedRed: 0.84, green: 0.91, blue: 0.98, alpha: 0.96).setFill()
    lensPath.fill()
    ctx.restoreGState()

    ctx.saveGState()
    lensPath.addClip()
    // Subtle blue glass gradient
    let glassColors = [
        NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 0.98).cgColor,
        NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.96, alpha: 0.96).cgColor
    ] as CFArray
    let glassGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glassColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(glassGrad, start: CGPoint(x: lensCenter.x - 100, y: lensCenter.y + 150), end: CGPoint(x: lensCenter.x + 100, y: lensCenter.y - 150), options: [])

    // Magnified text inside lens
    let bigNumFont = NSFont(name: "Courier-Bold", size: 68) ?? NSFont.monospacedSystemFont(ofSize: 68, weight: .bold)
    let bigSlugFont = NSFont(name: "Courier-Bold", size: 48) ?? NSFont.monospacedSystemFont(ofSize: 48, weight: .bold)
    ("12" as NSString).draw(at: CGPoint(x: lensCenter.x - 115, y: lensCenter.y + 42), withAttributes: [.font: bigNumFont, .foregroundColor: inkColor])
    ("INT. LIVING" as NSString).draw(at: CGPoint(x: lensCenter.x - 115, y: lensCenter.y - 38), withAttributes: [.font: bigSlugFont, .foregroundColor: inkColor])

    // Glossy glass highlight arc
    let gloss = NSBezierPath(ovalIn: CGRect(x: lensCenter.x - 135, y: lensCenter.y + 30, width: 230, height: 120))
    NSColor(white: 1.0, alpha: 0.35).setFill()
    gloss.fill()
    ctx.restoreGState()

    // Metallic Silver Rim
    NSColor(calibratedRed: 0.74, green: 0.78, blue: 0.84, alpha: 1.0).setStroke()
    lensPath.lineWidth = 22
    lensPath.stroke()

    NSColor(calibratedRed: 0.32, green: 0.36, blue: 0.44, alpha: 0.9).setStroke()
    lensPath.lineWidth = 4
    lensPath.stroke()

    NSGraphicsContext.restoreGraphicsState()
    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: path))
}

let base = ProcessInfo.processInfo.environment["GEMINI_WORKSPACE_DIR"]! + "/offline_reader/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: base)
try! FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_256x256.png", 256),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]
for (name, sz) in sizes {
    renderIcon(size: sz, to: base + "/" + name)
}
print("Iconset v2 ready")
