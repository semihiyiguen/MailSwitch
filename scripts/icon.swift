import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 70, y: 70, width: 884, height: 884)
        let background = NSBezierPath(roundedRect: rect, xRadius: 196, yRadius: 196)
        NSGradient(starting: NSColor(srgbRed: 0.17, green: 0.53, blue: 0.98, alpha: 1),
                   ending: NSColor(srgbRed: 0.23, green: 0.24, blue: 0.72, alpha: 1))!.draw(in: background, angle: -60)
        NSColor.white.setStroke()
        let envelope = NSBezierPath(roundedRect: NSRect(x: 230, y: 310, width: 564, height: 404), xRadius: 50, yRadius: 50)
        envelope.lineWidth = 32
        envelope.stroke()
        let flap = NSBezierPath()
        flap.move(to: NSPoint(x: 248, y: 684))
        flap.line(to: NSPoint(x: 512, y: 477))
        flap.line(to: NSPoint(x: 776, y: 684))
        flap.lineWidth = 32
        flap.lineJoinStyle = .round
        flap.stroke()
        NSColor(srgbRed: 0.15, green: 0.74, blue: 0.55, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 647, y: 216, width: 215, height: 215)).fill()
        NSColor.white.setStroke()
        let check = NSBezierPath()
        check.move(to: NSPoint(x: 703, y: 324))
        check.line(to: NSPoint(x: 740, y: 286))
        check.line(to: NSPoint(x: 807, y: 356))
        check.lineWidth = 23
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
