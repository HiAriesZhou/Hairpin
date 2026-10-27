import AppKit

/// Hairpin's mark: a bobby pin with a bow sitting on it, drawn as a template
/// image so it takes the menu bar's colors like any other menu bar icon. The
/// pin lies across the bottom, its upper prong crimped; the bow, two looped
/// outlines and a solid knot, sits on top; the whole is tilted a little.
enum HairpinIcon {
    static func image(side: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Hairpin"
        return image
    }

    private static func draw(in rect: NSRect) {
        let unit = min(rect.width, rect.height) / 18
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // Work on an 18-point grid around its center, tilted.
        var grid = AffineTransform(translationByX: rect.midX, byY: rect.midY)
        grid.scale(unit)
        grid.rotate(byDegrees: 12)
        let line: CGFloat = 1.3

        let pin = pinPath(center: NSPoint(x: 0, y: -3.9))
        pin.transform(using: grid)
        pin.lineWidth = line * unit
        pin.lineCapStyle = .round
        pin.lineJoinStyle = .round
        pin.stroke()

        var bowPlacement = grid
        bowPlacement.translate(x: 0, y: 1.5)
        let loops = loopsPath()
        loops.transform(using: bowPlacement)
        loops.lineWidth = line * unit
        loops.lineJoinStyle = .round
        loops.stroke()
        let knot = NSBezierPath(ovalIn: NSRect(x: -1.7, y: -1.7, width: 3.4, height: 3.4))
        knot.transform(using: bowPlacement)
        knot.fill()
    }

    /// A bobby pin lying along x around `center`: a plain lower prong and a
    /// crimped upper one, joined by a bend at the left, open at the right.
    private static func pinPath(center: NSPoint) -> NSBezierPath {
        let length: CGFloat = 14.6, gap: CGFloat = 2.6
        let left = center.x - length / 2, right = center.x + length / 2
        let top = center.y + gap / 2, bottom = center.y - gap / 2
        let path = NSBezierPath()
        path.move(to: NSPoint(x: right, y: bottom))
        path.line(to: NSPoint(x: left + gap / 2, y: bottom))
        path.appendArc(withCenter: NSPoint(x: left + gap / 2, y: center.y), radius: gap / 2,
                       startAngle: 270, endAngle: 90, clockwise: true)
        // The crimp shows on either side of the bow.
        let crimpStart = right - 4.6, waves = 2
        path.line(to: NSPoint(x: crimpStart, y: top))
        let step: CGFloat = 1.9
        for wave in 0..<waves {
            let start = crimpStart + CGFloat(wave) * step
            path.curve(to: NSPoint(x: start + step, y: top),
                       controlPoint1: NSPoint(x: start + step * 0.25, y: top - gap * 0.32),
                       controlPoint2: NSPoint(x: start + step * 0.75, y: top - gap * 0.5))
        }
        path.line(to: NSPoint(x: right, y: top))
        return path
    }

    /// The bow's two loops around a knot at the origin, as outlines: each
    /// leaves the knot's edge, swells up and out like an ear, and comes back
    /// low, clear of the pin.
    private static func loopsPath() -> NSBezierPath {
        let path = NSBezierPath()
        let inner: CGFloat = 2.0, reach: CGFloat = 5.4, up: CGFloat = 3.6, down: CGFloat = 1.5
        for side: CGFloat in [-1, 1] {
            path.move(to: NSPoint(x: side * inner, y: 0.55))
            path.curve(to: NSPoint(x: side * reach, y: up),
                       controlPoint1: NSPoint(x: side * (inner + 0.4), y: up * 1.05),
                       controlPoint2: NSPoint(x: side * reach * 0.75, y: up * 1.3))
            path.curve(to: NSPoint(x: side * reach * 0.92, y: -down),
                       controlPoint1: NSPoint(x: side * reach * 1.2, y: up * 0.55),
                       controlPoint2: NSPoint(x: side * reach * 1.15, y: -down * 0.6))
            path.curve(to: NSPoint(x: side * inner, y: -0.55),
                       controlPoint1: NSPoint(x: side * reach * 0.7, y: -down * 1.3),
                       controlPoint2: NSPoint(x: side * (inner + 0.6), y: -down * 1.1))
            path.close()
        }
        return path
    }
}
