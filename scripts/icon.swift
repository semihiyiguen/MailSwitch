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
        NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.40, blue: 0.48, alpha: 1),
                   ending: NSColor(srgbRed: 0.08, green: 0.13, blue: 0.26, alpha: 1))!.draw(in: background, angle: -65)
        // Layered mail card with a contrasting change badge: email defaults, not an inbox.
        NSColor(srgbRed: 0.40, green: 0.70, blue: 0.73, alpha: 0.45).setFill()
        NSBezierPath(roundedRect: NSRect(x: 205, y: 428, width: 560, height: 340), xRadius: 62, yRadius: 62).fill()
        let envelope = NSBezierPath(roundedRect: NSRect(x: 245, y: 334, width: 560, height: 360), xRadius: 56, yRadius: 56)
        NSColor(srgbRed: 0.97, green: 0.97, blue: 0.93, alpha: 1).setFill()
        envelope.fill()
        let flap = NSBezierPath()
        flap.move(to: NSPoint(x: 270, y: 658))
        flap.line(to: NSPoint(x: 525, y: 478))
        flap.line(to: NSPoint(x: 780, y: 658))
        flap.lineWidth = 29
        flap.lineJoinStyle = .round
        flap.lineCapStyle = .round
        NSColor(srgbRed: 0.12, green: 0.30, blue: 0.38, alpha: 1).setStroke()
        flap.stroke()
        NSColor(srgbRed: 0.08, green: 0.16, blue: 0.26, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 577, y: 174, width: 316, height: 316)).fill()
        NSColor(srgbRed: 1.0, green: 0.72, blue: 0.28, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 595, y: 192, width: 280, height: 280)).fill()
        let change = NSBezierPath()
        change.move(to: NSPoint(x: 664, y: 354))
        change.curve(to: NSPoint(x: 801, y: 367), controlPoint1: NSPoint(x: 687, y: 422), controlPoint2: NSPoint(x: 767, y: 425))
        change.move(to: NSPoint(x: 801, y: 404))
        change.line(to: NSPoint(x: 801, y: 367))
        change.line(to: NSPoint(x: 764, y: 367))
        change.move(to: NSPoint(x: 806, y: 310))
        change.curve(to: NSPoint(x: 669, y: 297), controlPoint1: NSPoint(x: 783, y: 242), controlPoint2: NSPoint(x: 703, y: 239))
        change.move(to: NSPoint(x: 669, y: 260))
        change.line(to: NSPoint(x: 669, y: 297))
        change.line(to: NSPoint(x: 706, y: 297))
        change.lineWidth = 24
        change.lineCapStyle = .round
        change.lineJoinStyle = .round
        NSColor(srgbRed: 0.10, green: 0.20, blue: 0.28, alpha: 1).setStroke()
        change.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
