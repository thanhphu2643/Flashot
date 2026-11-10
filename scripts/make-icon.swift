// Draws Resources/AppIcon.icns: a viewfinder with a lightning bolt on a blue-violet tile.
// Run: swift scripts/make-icon.swift
import AppKit

func render(_ size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    // Tile on Apple's icon grid: 824pt body, 100pt margin, soft drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.black.setFill()
    shape.fill()
    ctx.restoreGState()
    shape.addClip()
    NSGradient(colors: [NSColor(red: 0.09, green: 0.45, blue: 1, alpha: 1),
                        NSColor(red: 0.45, green: 0.22, blue: 0.95, alpha: 1)])!.draw(in: tile, angle: -60)
    // A faint highlight on the upper half.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: 100, y: 512, width: 824, height: 412), angle: -90)

    // Viewfinder corners.
    NSColor.white.setStroke()
    let inset: CGFloat = 250, arm: CGFloat = 120
    let (lo, hi) = (inset, 1024 - inset)
    for (x, y, dx, dy) in [(lo, lo, 1.0, 1.0), (hi, lo, -1.0, 1.0), (lo, hi, 1.0, -1.0), (hi, hi, -1.0, -1.0)] {
        let corner = NSBezierPath()
        corner.move(to: CGPoint(x: x, y: y + dy * arm))
        corner.line(to: CGPoint(x: x, y: y))
        corner.line(to: CGPoint(x: x + dx * arm, y: y))
        corner.lineWidth = 46
        corner.lineCapStyle = .round
        corner.lineJoinStyle = .round
        corner.stroke()
    }

    // Lightning bolt.
    let bolt = NSBezierPath()
    for (i, p) in [(560, 720), (390, 490), (500, 490), (450, 300), (640, 545), (525, 545), (585, 720)].enumerated() {
        let point = CGPoint(x: p.0, y: p.1)
        i == 0 ? bolt.move(to: point) : bolt.line(to: point)
    }
    bolt.close()
    bolt.lineJoinStyle = .round
    bolt.lineWidth = 18
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil) // one shadow for fill and stroke together
    NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1).set()
    bolt.fill()
    bolt.stroke()
    ctx.endTransparencyLayer()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! task.run()
task.waitUntilExit()
try! render(1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))
print("Wrote \(out.path)")
