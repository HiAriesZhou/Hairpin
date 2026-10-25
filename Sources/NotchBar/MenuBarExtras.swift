import AppKit
import ApplicationServices
import NotchBarCore

/// An extra read from another app, plus the live element to press.
struct LiveExtra {
    let item: ExtraItem
    let element: AXUIElement
}

/// Reads and presses other apps' menu bar extras via the Accessibility API.
enum MenuBarExtras {
    /// Per-app messaging timeout so a hung app can't stall the menu.
    private static let readTimeout: Float = 0.25
    private static let pressTimeout: Float = 1.0

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Enumerates the extras of every running app except our own.
    /// Reads NSRunningApplication on the main thread; the Accessibility
    /// queries themselves run concurrently.
    @MainActor
    static func all() -> [LiveExtra] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps: [(pid: pid_t, name: String, bundleID: String?)] = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier > 0 && $0.processIdentifier != ownPID && !$0.isTerminated }
            .map { ($0.processIdentifier, $0.localizedName ?? $0.bundleIdentifier ?? "PID \($0.processIdentifier)", $0.bundleIdentifier) }

        return query(apps)
    }

    /// Kept off the main actor: the closure below runs on worker threads.
    private static func query(_ apps: [(pid: pid_t, name: String, bundleID: String?)]) -> [LiveExtra] {
        let results = Collector()
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            let app = apps[index]
            results.append(extras(pid: app.pid, appName: app.name, bundleID: app.bundleID))
        }
        return results.items
    }

    private final class Collector {
        private let lock = NSLock()
        private(set) var items: [LiveExtra] = []

        func append(_ extras: [LiveExtra]) {
            guard !extras.isEmpty else { return }
            lock.lock()
            items.append(contentsOf: extras)
            lock.unlock()
        }
    }

    private static func extras(pid: pid_t, appName: String, bundleID: String?) -> [LiveExtra] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, readTimeout)
        guard let bar = element(app, "AXExtrasMenuBar"),
              let children = attribute(bar, "AXChildren") as? [AXUIElement] else { return [] }

        return children.enumerated().map { index, child in
            AXUIElementSetMessagingTimeout(child, readTimeout)
            let item = ExtraItem(
                id: "\(pid)-\(index)",
                pid: pid,
                appName: appName,
                bundleID: bundleID,
                role: string(child, "AXRole"),
                title: string(child, "AXTitle"),
                detail: string(child, "AXDescription"),
                help: string(child, "AXHelp"),
                frame: frame(child)
            )
            return LiveExtra(item: item, element: child)
        }
    }

    /// Opens the extra's menu: AXPress, falling back to AXShowMenu.
    /// Blocks until the target app answers, so call it off the main thread.
    static func open(_ element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, pressTimeout)
        let actions = actionNames(element)
        if actions.isEmpty || actions.contains("AXPress") {
            let result = AXUIElementPerformAction(element, "AXPress" as CFString)
            // .cannotComplete usually means the app is busy tracking the menu
            // we just opened; retrying with AXShowMenu would toggle it shut.
            if result == .success || result == .cannotComplete { return }
        }
        _ = AXUIElementPerformAction(element, "AXShowMenu" as CFString)
    }

    // MARK: - AX helpers

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, "AXPosition"), let size = attribute(element, "AXSize"),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    private static func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }
}

enum Screens {
    /// All displays in Quartz coordinates, with notch rects where present.
    @MainActor
    static func current() -> [ScreenInfo] {
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return [] }
        return screens.map { screen in
            let notch = Geometry.notchRect(screenFrame: screen.frame,
                                           topLeftArea: screen.auxiliaryTopLeftArea,
                                           topRightArea: screen.auxiliaryTopRightArea)
            return ScreenInfo(
                frame: Geometry.quartzRect(fromCocoa: screen.frame, primaryScreenHeight: primaryHeight),
                notch: notch.map { Geometry.quartzRect(fromCocoa: $0, primaryScreenHeight: primaryHeight) }
            )
        }
    }
}
