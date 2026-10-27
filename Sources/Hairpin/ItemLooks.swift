import AppKit
import HairpinCore

/// What each menu bar item looks like in the row: the shape captured while
/// it was shown (a hidden item isn't drawn), else its app's icon in grays.
///
/// Looks are keyed by the item's status window rather than its id, which is
/// its place among its app's items and shifts when the app adds or drops
/// one; the window stays the same while the item lives, wherever it moves
/// and whatever its title says. Capturing can turn on the screen recording
/// indicator, so each look is tried once, plus a couple of retries for one
/// caught moving, and forgotten when its window goes.
@MainActor
final class ItemLooks {
    struct Fingerprint: Hashable {
        let pid: pid_t
        let window: UInt32?
    }

    /// Lets a burst of menu bar changes settle into one capture.
    private static let captureDelay: TimeInterval = 1.5
    /// How often a look that comes out empty is tried again.
    private static let retries = 2
    private static let grayIconSide: CGFloat = 18

    private var captured: [Fingerprint: NSImage] = [:]
    private var attempted: Set<Fingerprint> = []
    private var misses: [Fingerprint: Int] = [:]
    private var grayIcons: [pid_t: NSImage] = [:]
    private var isCapturing = false
    private var captureTimer: Timer?
    /// The latest items, which a pending capture takes when it fires.
    private var items: [ClassifiedItem] = []

    static func fingerprint(of entry: ClassifiedItem) -> Fingerprint {
        Fingerprint(pid: entry.item.pid, window: entry.judgedWindowID)
    }

    func image(for entry: ClassifiedItem) -> NSImage? {
        if let image = captured[Self.fingerprint(of: entry)] { return image }
        if grayIcons[entry.item.pid] == nil { grayIcons[entry.item.pid] = Self.grayIcon(for: entry.item.pid) }
        return grayIcons[entry.item.pid]
    }

    /// Forgets the looks of items whose windows are gone, and the gray icons
    /// of apps that quit.
    func forget(exceptWindows windows: Set<UInt32>, pids running: Set<pid_t>) {
        let live: (Fingerprint) -> Bool = { fingerprint in fingerprint.window.map(windows.contains) ?? false }
        captured = captured.filter { live($0.key) }
        attempted = attempted.filter(live)
        misses = misses.filter { live($0.key) }
        grayIcons = grayIcons.filter { running.contains($0.key) }
    }

    /// Captures the looks of shown items not tried yet, once, after the menu
    /// bar has had a moment to settle, then calls `updated`. A capture
    /// already waiting isn't pushed back, so a busy menu bar still gets one.
    func capture(from items: [ClassifiedItem], updated: @escaping () -> Void) {
        self.items = items
        guard captureTimer == nil, IconCapture.isAvailable, !pending(in: items).isEmpty else { return }
        captureTimer = Timer.scheduledTimer(withTimeInterval: Self.captureDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.captureTimer = nil
                self.captureNow(from: self.items, updated: updated)
            }
        }
    }

    private func pending(in items: [ClassifiedItem]) -> [ClassifiedItem] {
        items.filter { entry in
            !entry.visibility.isHidden && entry.windowID != nil && entry.judgedWindowID != nil
                && !attempted.contains(Self.fingerprint(of: entry))
        }
    }

    private func captureNow(from items: [ClassifiedItem], updated: @escaping () -> Void) {
        guard #available(macOS 14, *), IconCapture.isAvailable, !isCapturing else { return }
        let owners = Dictionary(pending(in: items).compactMap { entry in
            entry.windowID.map { ($0, Self.fingerprint(of: entry)) }
        }, uniquingKeysWith: { first, _ in first })
        guard !owners.isEmpty else { return }
        attempted.formUnion(owners.values)
        isCapturing = true
        Task {
            let images = await IconCapture.images(of: Array(owners.keys))
            self.isCapturing = false
            for (window, fingerprint) in owners {
                if let image = images[window] {
                    self.captured[fingerprint] = image
                } else {
                    // Maybe caught moving: try again, a couple of times.
                    self.misses[fingerprint, default: 0] += 1
                    if self.misses[fingerprint]! <= Self.retries { self.attempted.remove(fingerprint) }
                }
            }
            updated()
        }
    }

    /// The app's icon in grays, to sit among monochrome menu bar icons.
    private static func grayIcon(for pid: pid_t) -> NSImage? {
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon,
              let tiff = icon.tiffRepresentation, let input = CIImage(data: tiff),
              let filter = CIFilter(name: "CIPhotoEffectMono") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: grayIconSide, height: grayIconSide))
    }
}
