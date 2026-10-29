import AppKit
import HairpinCore

/// What each menu bar item looks like in the row: the shape captured while
/// it was shown (a hidden item isn't drawn), else its app's own icon, else a
/// monochrome placeholder: the app's initial in a rounded square. (macOS 26
/// offers no other app's status item image, and an item kept behind the
/// notch is never drawn to be captured.) Apple's items all belong to one app,
/// so its icon wouldn't tell them apart; they keep the initial.
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
    private static let placeholderSide: CGFloat = 18
    /// Apps whose many items an app icon wouldn't tell apart.
    private static let systemItemOwners: Set<String> = ["com.apple.controlcenter", "com.apple.systemuiserver"]

    private var captured: [Fingerprint: NSImage] = [:]
    private var attempted: Set<Fingerprint> = []
    private var misses: [Fingerprint: Int] = [:]
    private var placeholders: [pid_t: NSImage] = [:]
    private var isCapturing = false
    private var captureTimer: Timer?
    /// The latest items, which a pending capture takes when it fires.
    private var items: [ClassifiedItem] = []

    static func fingerprint(of entry: ClassifiedItem) -> Fingerprint {
        Fingerprint(pid: entry.item.pid, window: entry.judgedWindowID)
    }

    func image(for entry: ClassifiedItem) -> NSImage? {
        if let image = captured[Self.fingerprint(of: entry)] { return image }
        if placeholders[entry.item.pid] == nil {
            placeholders[entry.item.pid] = Self.appIcon(pid: entry.item.pid)
                ?? Self.placeholder(for: entry.item.appName)
        }
        return placeholders[entry.item.pid]
    }

    /// Forgets the looks of items whose windows are gone, and the placeholders
    /// of apps that quit.
    func forget(exceptWindows windows: Set<UInt32>, pids running: Set<pid_t>) {
        let live: (Fingerprint) -> Bool = { fingerprint in fingerprint.window.map(windows.contains) ?? false }
        captured = captured.filter { live($0.key) }
        attempted = attempted.filter(live)
        misses = misses.filter { live($0.key) }
        placeholders = placeholders.filter { running.contains($0.key) }
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

    /// The app's own icon at the placeholder's size, if its bundle has one;
    /// the generic icon macOS draws otherwise says nothing about the item.
    private static func appIcon(pid: pid_t) -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: pid),
              !systemItemOwners.contains(app.bundleIdentifier ?? ""),
              let bundle = app.bundleURL.flatMap(Bundle.init(url:)),
              bundle.object(forInfoDictionaryKey: "CFBundleIconFile") != nil
                || bundle.object(forInfoDictionaryKey: "CFBundleIconName") != nil,
              let icon = app.icon?.copy() as? NSImage else { return nil }
        icon.size = NSSize(width: placeholderSide, height: placeholderSide)
        icon.accessibilityDescription = app.localizedName
        return icon
    }

    /// The app's initial in a rounded square, as a template image so it takes
    /// the same colors as the captured shapes beside it.
    private static func placeholder(for appName: String) -> NSImage {
        let initial = appName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
        let image = NSImage(size: NSSize(width: placeholderSide, height: placeholderSide), flipped: false) { rect in
            let line: CGFloat = 1.4
            let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 4.5, yRadius: 4.5)
            frame.lineWidth = line
            NSColor.black.setStroke()
            frame.stroke()
            let text = NSAttributedString(string: initial, attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.black,
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = appName
        return image
    }
}
