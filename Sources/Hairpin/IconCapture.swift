import AppKit
import ScreenCaptureKit
import os

private let log = Logger(subsystem: "com.hiarieszhou.hairpin", category: "capture")

/// Captures the real look of menu bar items. Needs Screen Recording permission
/// and macOS 14; without either, callers show the owning app's icon instead.
///
/// On macOS 26 an item's window holds none of its drawing, so the look comes
/// off the screen: the menu bar strip once as shown and once without the menu
/// bar's windows, and each item is the difference between the two, which
/// separates it from whatever wallpaper shows through the menu bar. Only a
/// drawn item can be captured; one hidden by the notch comes out blank.
///
/// ScreenCaptureKit is the only capture that draws third-party items with
/// their vibrancy (the window-list capture leaves them faint), but it turns
/// on the screen recording indicator, so callers capture sparingly.
enum IconCapture {
    private static let requestedKey = "RequestedScreenCapture"
    private static let settingsURLs = [
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture")!,
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!,
    ]
    /// The menu bar and status items sit at this window level and up.
    private static let menuBarLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
    /// A caught icon has pixels at least this opaque over the background…
    private static let minimumCore: CGFloat = 0.4
    /// …and leaves at least the rest of its window clear.
    private static let maximumCoverage: CGFloat = 0.7

    static var isAvailable: Bool {
        guard #available(macOS 14, *) else { return false }
        return CGPreflightScreenCaptureAccess()
    }

    /// Asks once through the system prompt; macOS won't show it again, so
    /// later requests open the Screen Recording pane.
    @MainActor
    static func requestAccess(openSettingsIfAsked: Bool) {
        if UserDefaults.standard.bool(forKey: requestedKey) {
            if openSettingsIfAsked { _ = settingsURLs.first { NSWorkspace.shared.open($0) } }
            return
        }
        UserDefaults.standard.set(true, forKey: requestedKey)
        CGRequestScreenCaptureAccess()
    }

    /// The shape of each drawn status window, trimmed to its drawing, as a
    /// template image so it's drawn like a menu bar icon. Windows that aren't
    /// drawn, or can't be captured, are left out.
    @available(macOS 14, *)
    @MainActor
    static func images(of windowIDs: [UInt32]) async -> [UInt32: NSImage] {
        guard !windowIDs.isEmpty,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        else { return [:] }
        let wanted = Set(windowIDs)
        let targets = content.windows.filter { wanted.contains($0.windowID) && $0.isOnScreen }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let own = content.windows.filter { $0.owningApplication?.processID == ownPID }
        let menuBar = content.windows.filter { $0.windowLayer >= menuBarLevel }

        var images: [UInt32: NSImage] = [:]
        for display in content.displays {
            let onDisplay = targets.filter { display.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            guard let strip = onDisplay.map(\.frame).reduce(nil, { $0?.union($1) ?? $1 }) else { continue }
            let local = strip.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
            let shownFilter = SCContentFilter(display: display, excludingWindows: own)
            let scale = CGFloat(shownFilter.pointPixelScale)
            guard let shown = await capture(shownFilter, rect: local, scale: scale),
                  let behind = await capture(SCContentFilter(display: display, excludingWindows: menuBar),
                                             rect: local, scale: scale),
                  shown.width == behind.width, shown.height == behind.height else {
                log.debug("capture of display \(display.displayID) failed")
                continue
            }
            for window in onDisplay {
                let points = window.frame.offsetBy(dx: -strip.minX, dy: -strip.minY)
                let rect = CGRect(x: (points.minX * scale).rounded(), y: (points.minY * scale).rounded(),
                                  width: (points.width * scale).rounded(), height: (points.height * scale).rounded())
                guard let image = separate(shown, from: behind, in: rect, scale: scale) else {
                    log.debug("capture \(window.windowID): blank")
                    continue
                }
                images[window.windowID] = image
            }
        }
        log.debug("captured \(images.count) of \(windowIDs.count) items")
        return images
    }

    @available(macOS 14, *)
    private static func capture(_ filter: SCContentFilter, rect: CGRect, scale: CGFloat) async -> Bitmap? {
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int((rect.width * scale).rounded())
        config.height = Int((rect.height * scale).rounded())
        config.showsCursor = false
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        else { return nil }
        return Bitmap(image)
    }

    /// Recovers the item's shape over the background: per pixel, the least
    /// opacity that explains the change, less the faint tint the menu bar
    /// itself lays over the whole strip (read off the window's edges, which
    /// the icon doesn't reach). Menu bar icons draw their core solid, so the
    /// most opaque pixel is taken as fully opaque, which keeps a capture as
    /// crisp as the icon in the menu bar. A capture with no solid core, or
    /// opaque nearly all over, didn't catch the icon (it wasn't drawn, or was
    /// moving) and is dropped. Only the shape is kept; it's drawn as a template.
    private static func separate(_ shown: Bitmap, from behind: Bitmap, in rect: CGRect, scale: CGFloat) -> NSImage? {
        let minX = max(Int(rect.minX), 0), minY = max(Int(rect.minY), 0)
        let maxX = min(Int(rect.maxX), shown.width), maxY = min(Int(rect.maxY), shown.height)
        guard maxX > minX, maxY > minY else { return nil }
        let width = maxX - minX, height = maxY - minY
        var alphas = [CGFloat](repeating: 0, count: width * height)
        for y in minY..<maxY {
            for x in minX..<maxX {
                let a = shown.rgb(x, y), b = behind.rgb(x, y)
                var alpha: CGFloat = 0
                for c in 0..<3 {
                    let d = a[c] - b[c]
                    let bound = d > 0 ? d / max(1 - b[c], 0.001) : -d / max(b[c], 0.001)
                    alpha = max(alpha, min(bound, 1))
                }
                alphas[(y - minY) * width + (x - minX)] = alpha
            }
        }
        var edge: [CGFloat] = []
        for x in 0..<width { edge += [alphas[x], alphas[(height - 1) * width + x]] }
        for y in 0..<height { edge += [alphas[y * width], alphas[y * width + width - 1]] }
        let tint = edge.sorted()[edge.count / 2]
        let shape = alphas.map { max(($0 - tint) / max(1 - tint, 0.001), 0) }
        let strongest = shape.max() ?? 0
        // Compression noise and wallpaper shimmer stay transparent.
        let drawnPixels = shape.filter { $0 > 0.08 }.count
        guard strongest > Self.minimumCore, CGFloat(drawnPixels) < Self.maximumCoverage * CGFloat(shape.count)
        else { return nil }
        var item = Bitmap(width: width, height: height)
        for i in shape.indices where shape[i] > 0.08 {
            item.set(i % width, i / width, rgb: [0, 0, 0], alpha: min(shape[i] / strongest, 1))
        }
        guard let drawn = item.drawnBounds(), let image = item.cgImage()?.cropping(to: drawn) else { return nil }
        let result = NSImage(cgImage: image, size: NSSize(width: drawn.width / scale, height: drawn.height / scale))
        result.isTemplate = true
        return result
    }
}

/// Premultiplied RGBA pixels in sRGB, top row first.
private struct Bitmap {
    let width: Int
    let height: Int
    var data: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        data = [UInt8](repeating: 0, count: width * height * 4)
    }

    init?(_ image: CGImage) {
        self.init(width: image.width, height: image.height)
        let (width, height) = (self.width, self.height)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = Self.context(buffer.baseAddress, width: width, height: height) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
    }

    /// The color at a pixel, components 0…1; the captures are opaque.
    func rgb(_ x: Int, _ y: Int) -> [CGFloat] {
        let i = (y * width + x) * 4
        return (0..<3).map { CGFloat(data[i + $0]) / 255 }
    }

    mutating func set(_ x: Int, _ y: Int, rgb: [CGFloat], alpha: CGFloat) {
        let i = (y * width + x) * 4
        for c in 0..<3 { data[i + c] = UInt8((rgb[c] * alpha * 255).rounded()) }
        data[i + 3] = UInt8((alpha * 255).rounded())
    }

    /// The smallest rect holding every visible pixel, top-left origin.
    func drawnBounds() -> CGRect? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where data[(y * width + x) * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func cgImage() -> CGImage? {
        var copy = data
        let (width, height) = (self.width, self.height)
        return copy.withUnsafeMutableBytes { buffer in
            Self.context(buffer.baseAddress, width: width, height: height)?.makeImage()
        }
    }

    private static func context(_ data: UnsafeMutableRawPointer?, width: Int, height: Int) -> CGContext? {
        CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}
