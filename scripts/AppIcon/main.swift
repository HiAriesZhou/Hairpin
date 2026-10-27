import AppKit

// Renders Hairpin's app icon, a bobby pin with a satin bow on a cream
// tile, into every size a macOS .iconset holds. It's the menu bar mark
// drawn in full color. Usage: make-icon <output.iconset>
//
// Drawn on Apple's 1024-point icon grid: an 824-point rounded square, inset
// 100 points, with the standard drop shadow, so macOS shows it as is rather
// than inside a gray tile.

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon <output.iconset>\n".data(using: .utf8)!)
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185
func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let creamTop = rgb(0xFFF6EE), creamBottom = rgb(0xFFE1E6)
let satin = rgb(0xF4567E), satinLight = rgb(0xFF8FAB), satinFold = rgb(0xC2345C)
let steel = rgb(0x3B3852), steelShine = rgb(0x8E89A8)

/// Where the bow's knot, the pin's head, sits; the pin runs down and right.
let head = NSPoint(x: 440, y: 596)
let bowScale: CGFloat = 0.9
let pinAngle: CGFloat = -38

/// Pixels per grid point of the size being rendered. Shadows are set in
/// pixels, unscaled by the drawing transform, so they're scaled by hand.
var pixelScale: CGFloat = 1

func withShadow(_ color: NSColor, blur: CGFloat, y: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur * pixelScale
    shadow.shadowOffset = NSSize(width: 0, height: y * pixelScale)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func placed(_ path: NSBezierPath, at point: NSPoint, rotated degrees: CGFloat) -> NSBezierPath {
    var transform = AffineTransform(translationByX: point.x, byY: point.y)
    transform.rotate(byDegrees: degrees)
    path.transform(using: transform)
    return path
}

/// The pin along +x from its head: a plain lower prong and a crimped upper
/// one joined by a bend behind the head.
func pinPath(length: CGFloat, gap: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: length, y: -gap / 2))
    path.line(to: NSPoint(x: 0, y: -gap / 2))
    path.appendArc(withCenter: .zero, radius: gap / 2, startAngle: 270, endAngle: 90, clockwise: true)
    let crimpStart = length * 0.38, crimpEnd = length * 0.86, waves = 3
    path.line(to: NSPoint(x: crimpStart, y: gap / 2))
    let step = (crimpEnd - crimpStart) / CGFloat(waves)
    for wave in 0..<waves {
        let start = crimpStart + CGFloat(wave) * step
        path.curve(to: NSPoint(x: start + step, y: gap / 2),
                   controlPoint1: NSPoint(x: start + step * 0.25, y: -gap * 0.05),
                   controlPoint2: NSPoint(x: start + step * 0.75, y: -gap * 0.05))
    }
    path.line(to: NSPoint(x: length, y: gap / 2))
    return path
}

func drawPin() {
    let length: CGFloat = 520, gap: CGFloat = 84, line: CGFloat = 40
    withShadow(rgb(0x5A2A40, 0.28), blur: 22, y: -14) {
        let pin = placed(pinPath(length: length, gap: gap), at: head, rotated: pinAngle)
        pin.lineWidth = line
        pin.lineCapStyle = .round
        pin.lineJoinStyle = .round
        steel.setStroke()
        pin.stroke()
        // Rounded tips at the open end.
        steel.setFill()
        for y in [gap / 2, -gap / 2] {
            placed(NSBezierPath(ovalIn: NSRect(x: length - 28, y: y - 28, width: 56, height: 56)),
                   at: head, rotated: pinAngle).fill()
        }
    }
    // A sheen along the metal.
    let shine = placed(pinPath(length: length, gap: gap), at: NSPoint(x: head.x - 4, y: head.y + 7), rotated: pinAngle)
    shine.lineWidth = 9
    shine.lineCapStyle = .round
    shine.lineJoinStyle = .round
    steelShine.withAlphaComponent(0.7).setStroke()
    shine.stroke()
}

/// One loop of the bow, to the right of a knot at the origin.
func loopPath(scale: CGFloat) -> NSBezierPath {
    let inner: CGFloat = 40 * scale, reach: CGFloat = 230 * scale, up: CGFloat = 150 * scale, down: CGFloat = 120 * scale
    let path = NSBezierPath()
    path.move(to: NSPoint(x: inner, y: 26 * scale))
    path.curve(to: NSPoint(x: reach, y: up),
               controlPoint1: NSPoint(x: inner + 40 * scale, y: up * 1.0),
               controlPoint2: NSPoint(x: reach * 0.72, y: up * 1.32))
    path.curve(to: NSPoint(x: reach * 0.94, y: -down),
               controlPoint1: NSPoint(x: reach * 1.24, y: up * 0.5),
               controlPoint2: NSPoint(x: reach * 1.2, y: -down * 0.55))
    path.curve(to: NSPoint(x: inner, y: -26 * scale),
               controlPoint1: NSPoint(x: reach * 0.68, y: -down * 1.28),
               controlPoint2: NSPoint(x: inner + 40 * scale, y: -down * 1.0))
    path.close()
    return path
}

func mirrored(_ path: NSBezierPath) -> NSBezierPath {
    let copy = path.copy() as! NSBezierPath
    copy.transform(using: AffineTransform(scaleByX: -1, byY: 1))
    return copy
}

func drawBow() {
    let tilt: CGFloat = 14
    let loops = [loopPath(scale: bowScale), mirrored(loopPath(scale: bowScale))].map { placed($0, at: head, rotated: tilt) }
    let tails = [tailPath(), mirrored(tailPath())].map { tail -> NSBezierPath in
        tail.transform(using: AffineTransform(scale: bowScale))
        return placed(tail, at: head, rotated: tilt)
    }
    withShadow(rgb(0x7A1F3D, 0.3), blur: 26, y: -16) {
        satinFold.setFill()
        tails.forEach { $0.fill() }
        satin.setFill()
        loops.forEach { $0.fill() }
    }
    // Light across the top of each loop, a fold where it gathers at the knot.
    for loop in loops {
        NSGraphicsContext.saveGraphicsState()
        loop.addClip()
        NSGradient(colors: [satinLight, satin.withAlphaComponent(0)])?.draw(in: loop.bounds, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
    }
    for fold in [loopPath(scale: bowScale * 0.5), mirrored(loopPath(scale: bowScale * 0.5))] {
        satinFold.withAlphaComponent(0.55).setFill()
        placed(fold, at: head, rotated: tilt).fill()
    }
    let knotSize = NSSize(width: 112 * bowScale, height: 128 * bowScale)
    let knot = placed(NSBezierPath(roundedRect: NSRect(x: -knotSize.width / 2, y: -knotSize.height / 2,
                                                       width: knotSize.width, height: knotSize.height),
                                   xRadius: 48 * bowScale, yRadius: 48 * bowScale),
                      at: head, rotated: tilt)
    withShadow(rgb(0x7A1F3D, 0.35), blur: 10, y: -4) {
        satin.setFill()
        knot.fill()
    }
    NSGraphicsContext.saveGraphicsState()
    knot.addClip()
    NSGradient(colors: [satinLight, satinFold])?.draw(in: knot.bounds, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
}

/// A ribbon tail hanging down and out from the knot, cut in a V.
func tailPath() -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 10, y: -30))
    path.line(to: NSPoint(x: 62, y: -40))
    path.line(to: NSPoint(x: 150, y: -250))
    path.line(to: NSPoint(x: 112, y: -222))
    path.line(to: NSPoint(x: 84, y: -268))
    path.close()
    return path
}

func drawIcon() {
    let shape = NSBezierPath(roundedRect: tile, xRadius: cornerRadius, yRadius: cornerRadius)
    withShadow(NSColor.black.withAlphaComponent(0.3), blur: 28, y: -10) {
        creamTop.setFill()
        shape.fill()
    }
    NSGradient(starting: creamTop, ending: creamBottom)?.draw(in: shape, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    drawPin()
    drawBow()
    NSGraphicsContext.restoreGraphicsState()
}

func png(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    pixelScale = CGFloat(pixels) / 1024
    context.cgContext.scaleBy(x: pixelScale, y: pixelScale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    return data
}

for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: output.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: output.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
