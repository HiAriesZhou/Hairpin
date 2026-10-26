import AppKit
import ApplicationServices
import HairpinCore

/// An extra read from another app, plus the live element to press.
///
/// `@unchecked`: `AXUIElement` isn't annotated `Sendable`, but CF reference
/// counting is thread-safe and the element is only ever handed to AX calls.
struct LiveExtra: @unchecked Sendable {
    let item: ExtraItem
    let element: AXUIElement
}

/// A running app, captured on the main thread for a background scan.
struct RunningApp: Sendable {
    let pid: pid_t
    let name: String
    let bundleID: String?
}

/// Reads and presses other apps' menu bar extras via the Accessibility API.
enum MenuBarExtras {
    /// Messaging timeout for every element we read. It applies per element,
    /// so it is set on each one before it is messaged.
    private static let readTimeout: Float = 0.25
    private static let pressTimeout: Float = 1.0

    static var isTrusted: Bool { AXIsProcessTrusted() }

    struct Scan: Sendable {
        var extras: [LiveExtra]
        /// Union of the menu bar owner's menu frames (Quartz), if readable.
        var appMenus: CGRect?
    }

    /// Every running app except our own.
    @MainActor
    static func runningApps() -> [RunningApp] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier > 0 && $0.processIdentifier != ownPID && !$0.isTerminated }
            .map { RunningApp(pid: $0.processIdentifier,
                              name: $0.localizedName ?? $0.bundleIdentifier ?? "PID \($0.processIdentifier)",
                              bundleID: $0.bundleIdentifier) }
    }

    /// Reads every app's extras, plus the menus of the app that owns the menu
    /// bar. Blocks on Accessibility round trips, so never call it on the main
    /// thread.
    static func scan(_ apps: [RunningApp], menuBarOwner: pid_t?) -> Scan {
        let results = Collector()
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            results.append(extras(of: apps[index]))
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let menus = menuBarOwner.flatMap { $0 == ownPID ? nil : menuFrame(pid: $0) }
        return Scan(extras: results.items, appMenus: menus)
    }

    /// `@unchecked`: all access to `items` goes through `lock`, except the
    /// read after `concurrentPerform` has returned.
    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var items: [LiveExtra] = []

        func append(_ extras: [LiveExtra]) {
            guard !extras.isEmpty else { return }
            lock.lock()
            items.append(contentsOf: extras)
            lock.unlock()
        }
    }

    private static func extras(of app: RunningApp) -> [LiveExtra] {
        let root = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(root, readTimeout)
        guard let bar = element(root, "AXExtrasMenuBar") else { return [] }
        AXUIElementSetMessagingTimeout(bar, readTimeout)
        guard let children = attribute(bar, "AXChildren") as? [AXUIElement] else { return [] }

        return children.enumerated().map { index, child in
            AXUIElementSetMessagingTimeout(child, readTimeout)
            let item = ExtraItem(
                id: "\(app.pid)-\(index)",
                pid: app.pid,
                appName: app.name,
                bundleID: app.bundleID,
                role: string(child, "AXRole"),
                title: string(child, "AXTitle"),
                detail: string(child, "AXDescription"),
                help: string(child, "AXHelp"),
                frame: frame(child)
            )
            return LiveExtra(item: item, element: child)
        }
    }

    /// The span of an app's menus in the menu bar, Apple menu included.
    private static func menuFrame(pid: pid_t) -> CGRect? {
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, readTimeout)
        guard let bar = element(root, "AXMenuBar") else { return nil }
        AXUIElementSetMessagingTimeout(bar, readTimeout)
        guard let children = attribute(bar, "AXChildren") as? [AXUIElement] else { return nil }

        let frames = children.compactMap { child -> CGRect? in
            AXUIElementSetMessagingTimeout(child, readTimeout)
            return frame(child)
        }.filter { $0.width > 0 && $0.height > 0 }
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }

    /// Opens the extra's menu: AXPress, falling back to AXShowMenu.
    /// Blocks until the target app answers, so call it off the main thread.
    static func open(_ extra: LiveExtra) {
        let element = extra.element
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
