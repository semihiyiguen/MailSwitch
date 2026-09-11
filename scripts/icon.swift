import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 70, y: 70, width: 884, height: 884)
        let background = NSBezierPath(roundedRect: rect, xRadius: 196, yRadius: 196)
        NSGradient(starting: NSColor(srgbRed: 0.40, green: 0.22, blue: 0.86, alpha: 1),
                   ending: NSColor(srgbRed: 0.10, green: 0.08, blue: 0.24, alpha: 1))!.draw(in: background, angle: -70)
        // A switch and opposing arrows identify a settings utility, not a mail client.
        let track = NSBezierPath(roundedRect: NSRect(x: 204, y: 363, width: 616, height: 298), xRadius: 149, yRadius: 149)
        NSGradient(starting: NSColor(srgbRed: 0.14, green: 0.76, blue: 0.74, alpha: 1),
                   ending: NSColor(srgbRed: 0.39, green: 0.94, blue: 0.77, alpha: 1))!.draw(in: track, angle: 0)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 542, y: 391, width: 242, height: 242)).fill()
        let arrows = NSBezierPath()
        arrows.move(to: NSPoint(x: 264, y: 749))
        arrows.line(to: NSPoint(x: 747, y: 749))
        arrows.move(to: NSPoint(x: 670, y: 824))
        arrows.line(to: NSPoint(x: 747, y: 749))
        arrows.line(to: NSPoint(x: 670, y: 674))
        arrows.move(to: NSPoint(x: 760, y: 275))
        arrows.line(to: NSPoint(x: 277, y: 275))
        arrows.move(to: NSPoint(x: 354, y: 350))
        arrows.line(to: NSPoint(x: 277, y: 275))
        arrows.line(to: NSPoint(x: 354, y: 200))
        arrows.lineWidth = 43
        arrows.lineCapStyle = .round
        arrows.lineJoinStyle = .round
        NSColor.white.withAlphaComponent(0.95).setStroke()
        arrows.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
