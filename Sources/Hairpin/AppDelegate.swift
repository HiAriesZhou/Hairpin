import AppKit
import ApplicationServices
import HairpinCore
import ServiceManagement
import os

private let log = Logger(subsystem: "com.hiarieszhou.hairpin", category: "scan")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let stack = NotchStack()

    /// Items hidden by the notch, from the latest finished scan; nil until the
    /// first scan finishes. The stack is built only from this, so it never
    /// waits on another app.
    private var hidden: [ClassifiedItem]?
    /// Every item in the menu bar, hidden or not, from the latest scan.
    private var kept: [ClassifiedItem] = []
    /// The extras behind `hidden`, by item id.
    private var extras: [String: LiveExtra] = [:]
    /// Real-look icons by item id, kept across scans. A hidden item's window
    /// isn't drawn, so its look is captured while it's still shown.
    private var captured: [String: NSImage] = [:]
    /// Gray app icons by PID, for items without a captured look.
    private var grayIcons: [pid_t: NSImage] = [:]
    private var isCapturing = false
    /// Items already tried, so one that comes out blank isn't captured again.
    private var attempted: Set<String> = []
    private var captureTimer: Timer?
    /// Lets a burst of menu bar changes settle into one capture.
    private static let captureDelay: TimeInterval = 1.5
    /// How often an item that comes out empty is tried again.
    private static let captureRetries = 2
    private var misses: [String: Int] = [:]
    /// Where the stack goes, from the latest scan.
    private var anchor: StackAnchor?
    private var isScanning = false
    private var scanAgain = false
    private let scanQueue = DispatchQueue(label: "com.hiarieszhou.hairpin.scan", qos: .userInitiated)

    private static let autosaveName = "Hairpin"
    private static let menusSettleDelay: TimeInterval = 0.4
    private static let openOnHoverKey = "OpenOnHover"
    /// The macOS 13+ Privacy & Security pane first, the legacy pane id second.
    private static let accessibilitySettingsURLs = [
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!,
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        dropRightmostPosition()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = Self.autosaveName
        statusItem.button?.image = HairpinIcon.image()
        statusItem.button?.toolTip = "Hairpin"
        menu.delegate = self
        menu.autoenablesItems = false
        // Clicks are ours to route: our icon can hold the hidden items too.
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            stack.attach(to: button)
        }
        UserDefaults.standard.register(defaults: [Self.openOnHoverKey: true])
        stack.opensOnHover = UserDefaults.standard.bool(forKey: Self.openOnHoverKey)
        stack.onExpand = { [weak self] in self?.stackWillExpand() }
        stack.onSelect = { [weak self] id in self?.openExtra(id: id) }

        // Keep the snapshot fresh: the stack shows whenever something is hidden.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            workspace.addObserver(self, selector: #selector(environmentChanged(_:)), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(environmentChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        if MenuBarExtras.isTrusted {
            refresh()
        } else {
            // The menu is rebuilt on every open, so it picks up the grant by itself.
            showAccessibilityAlert()
        }
    }

    /// Opening Hairpin.app again (Finder, Spotlight, Launchpad) while it runs
    /// fans out the hidden items, or shows the menu at the pointer when none
    /// are hidden: a way in if our own icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task {
            if self.hidden?.isEmpty == false {
                self.stack.expand(pinned: true)
            } else {
                _ = self.menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            }
        }
        return false
    }

    /// Earlier builds asked AppKit for the slot next to the system items
    /// through the undocumented default it keeps ⌘-drag positions in
    /// (distance from the right edge), which put our icon right of Apple's.
    /// New items start at the left end, where the hidden ones are kept, so
    /// that request is withdrawn; a position the user dragged to is kept.
    private func dropRightmostPosition() {
        let key = "NSStatusItem Preferred Position \(Self.autosaveName)"
        if UserDefaults.standard.object(forKey: key) as? Double == 0 {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Scanning

    @objc private func environmentChanged(_ notification: Notification) {
        refresh()
        // A newly active app's menus can land in the menu bar a moment later,
        // changing where the hidden items fit; look again once they have.
        if notification.name == NSWorkspace.didActivateApplicationNotification {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.menusSettleDelay) { [weak self] in
                self?.refresh()
            }
        }
    }

    /// Starts a background scan. A request made while one is running queues
    /// one more, so the result always reflects the latest state.
    private func refresh() {
        guard MenuBarExtras.isTrusted else { return }
        guard !isScanning else {
            scanAgain = true
            return
        }
        isScanning = true
        let apps = MenuBarExtras.runningApps()
        let owner = NSWorkspace.shared.menuBarOwningApplication?.processIdentifier
        scanQueue.async {
            let scan = MenuBarExtras.scan(apps, menuBarOwner: owner)
            Task { @MainActor in self.finish(scan) }
        }
    }

    private func finish(_ scan: MenuBarExtras.Scan) {
        isScanning = false
        let ownBundleID = Bundle.main.bundleIdentifier.map { Set([$0]) } ?? []
        let items = ExtraList.filter(scan.extras.map(\.item),
                                     excludingPIDs: [ProcessInfo.processInfo.processIdentifier],
                                     excludingBundleIDs: ownBundleID)
        let screens = Screens.current()
        let sorted = ExtraList.classifyAndSort(items, screens: screens, appMenus: scan.appMenus,
                                               windows: scan.windows.isEmpty ? nil : scan.windows)
        logScan(items: items, sorted: sorted, windows: scan.windows)
        kept = sorted
        let ownFrame = (statusItem.button?.window?.frame).map { frame in
            Geometry.quartzRect(fromCocoa: frame, primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0)
        }
        anchor = Screens.stackAnchor(screens: screens, windows: scan.windows, appMenus: scan.appMenus, own: ownFrame)
        // The item under the pin, if it had to sit on one, is kept with the hidden ones.
        let covered = anchor?.covered.flatMap { covered in
            sorted.first { !$0.visibility.isHidden && abs(($0.frame?.minX ?? .infinity) - covered.minX) <= 2 }
        }
        let overflowed = sorted.filter(\.visibility.isHidden) + (covered.map { [$0] } ?? [])
        let launchDates = Dictionary(overflowed.compactMap { entry in
            NSRunningApplication(processIdentifier: entry.item.pid)?.launchDate.map { (entry.item.pid, $0) }
        }, uniquingKeysWith: { first, _ in first })
        hidden = ExtraList.inMenuBarOrder(overflowed, launchDates: launchDates)
        extras = Dictionary(scan.extras.map { ($0.item.id, $0) }, uniquingKeysWith: { first, _ in first })
        log.debug("""
            stack place: \(self.anchor.map { "\($0.place)" } ?? "none", privacy: .public), \
            covering: \(covered?.item.appName ?? "-", privacy: .public), \
            app menus end at \(scan.appMenus.map { "\($0.maxX)" } ?? "?", privacy: .public)
            """)
        updateStack()
        scheduleCapture()
        if scanAgain {
            scanAgain = false
            refresh()
        }
    }

    /// Debug-level only: `log stream --level debug --predicate 'subsystem == "com.hiarieszhou.hairpin"'`.
    private func logScan(items: [ExtraItem], sorted: [ClassifiedItem], windows: [StatusWindow]) {
        let kept = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        log.debug("scan: \(items.count) items, \(windows.count) status windows, \(sorted.count) kept")
        for item in items {
            let entry = kept[item.id]
            log.debug("""
                \(item.appName, privacy: .public) \(item.id, privacy: .public) \
                frame=\(item.frame.map { "\($0)" } ?? "nil", privacy: .public) \
                window=\(entry?.windowID.map(String.init) ?? "-", privacy: .public) \
                visibility=\(entry.map { "\($0.visibility)" } ?? "dropped", privacy: .public)
                """)
        }
    }

    // MARK: - Stack

    private func stackWillExpand() {
        refresh()
        // The first time something is hidden and fanned out, ask to show it as it looks.
        if #available(macOS 14, *), !IconCapture.isAvailable { IconCapture.requestAccess(openSettingsIfAsked: false) }
    }

    private func updateStack() {
        if let button = statusItem.button {
            let name = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
            stack.appearance = NSAppearance(named: name)
        }
        stack.update(stackEntries(), anchor: anchor)
        statusItem.button?.toolTip = stack.usesButton
            ? "Hairpin — click for hidden icons, right-click for settings" : "Hairpin"
    }

    private func stackEntries() -> [StackEntry] {
        (hidden ?? []).compactMap { entry in
            let image = captured[entry.item.id] ?? {
                if grayIcons[entry.item.pid] == nil { grayIcons[entry.item.pid] = icon(for: entry.item.pid, size: 18) }
                return grayIcons[entry.item.pid]
            }()
            guard let image else { return nil }
            return StackEntry(id: entry.item.id, image: image, toolTip: entry.item.displayName)
        }
    }

    /// Captures the look of shown items not tried yet, so it's at hand once
    /// they overflow, after the menu bar settles. Capturing turns on the
    /// screen recording indicator, so it happens only when new items show up.
    private func scheduleCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        guard IconCapture.isAvailable, !pendingCaptures().isEmpty else { return }
        captureTimer = Timer.scheduledTimer(withTimeInterval: Self.captureDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.captureIcons() }
        }
    }

    private func pendingCaptures() -> [ClassifiedItem] {
        kept.filter { !$0.visibility.isHidden && $0.windowID != nil && !attempted.contains($0.id) }
    }

    private func captureIcons() {
        guard #available(macOS 14, *), IconCapture.isAvailable, !isCapturing else { return }
        let wanted = pendingCaptures()
        guard !wanted.isEmpty else { return }
        let owners = Dictionary(wanted.compactMap { entry in entry.windowID.map { ($0, entry.id) } },
                                uniquingKeysWith: { first, _ in first })
        attempted.formUnion(wanted.map(\.id))
        isCapturing = true
        Task {
            let images = await IconCapture.images(of: Array(owners.keys))
            self.isCapturing = false
            let ids = Set(self.kept.map(\.id))
            self.attempted.formIntersection(ids)
            var captured = self.captured.filter { ids.contains($0.key) }
            let pids = Set(self.kept.map(\.item.pid))
            self.grayIcons = self.grayIcons.filter { pids.contains($0.key) }
            for (window, image) in images { if let id = owners[window] { captured[id] = image } }
            // An item that came out empty is tried again, a couple of times, as
            // it may have been caught moving.
            for id in owners.filter({ images[$0.key] == nil }).map(\.value) {
                self.misses[id, default: 0] += 1
                if self.misses[id]! <= Self.captureRetries { self.attempted.remove(id) }
            }
            self.captured = captured
            self.updateStack()
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        stack.collapse()
        refresh()
    }

    /// Settings only; the hidden items live in the bar.
    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        if !MenuBarExtras.isTrusted {
            menu.addItem(action("Grant Accessibility…", #selector(grantAccessibility), symbol: "lock.shield"))
        } else {
            menu.addItem(header(Self.status(hiddenCount: hidden?.count)))
            if #available(macOS 14, *), !IconCapture.isAvailable {
                menu.addItem(action("Show Real Icons…", #selector(grantScreenCapture), symbol: "eye"))
            }
        }

        menu.addItem(.separator())
        let hover = action("Open on Hover", #selector(toggleOpenOnHover))
        hover.state = stack.opensOnHover ? .on : .off
        hover.toolTip = "Show hidden icons when the pointer rests on the pin; a click always does"
        menu.addItem(hover)
        let login = action("Launch at Login", #selector(toggleLaunchAtLogin))
        switch SMAppService.mainApp.status {
        case .enabled:
            login.state = .on
        case .requiresApproval:
            login.state = .mixed
            login.toolTip = "Waiting for approval in System Settings › General › Login Items"
        default:
            login.state = .off
        }
        menu.addItem(login)
        let quitItem = NSMenuItem(title: "Quit Hairpin", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private static func status(hiddenCount: Int?) -> String {
        switch hiddenCount {
        case nil: return "Reading menu bar items…"
        case 0?: return "No icons hidden by the notch"
        case 1?: return "1 icon hidden"
        case let count?: return "\(count) icons hidden"
        }
    }

    private func action(_ title: String, _ selector: Selector, symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        return item
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// The app's icon in grays, to sit among monochrome menu bar icons.
    private func icon(for pid: pid_t, size: CGFloat) -> NSImage? {
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon,
              let tiff = icon.tiffRepresentation, let input = CIImage(data: tiff),
              let filter = CIFilter(name: "CIPhotoEffectMono") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    // MARK: - Actions

    private func openExtra(id: String) {
        guard let extra = extras[id] else { return }
        // Let our click finish, then press off the main thread:
        // AXPress blocks while the target app opens its menu.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            MenuBarExtras.open(extra)
        }
    }

    @objc private func grantAccessibility() {
        showAccessibilityAlert()
    }

    /// Our icon: while it holds the hidden items, a click shows them and a
    /// right-click (or Control-click) the settings; otherwise any click shows
    /// the settings, right under the icon.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if stack.usesButton && !wantsMenu {
            stack.toggle()
        } else {
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        }
    }

    @objc private func toggleOpenOnHover() {
        stack.opensOnHover.toggle()
        UserDefaults.standard.set(stack.opensOnHover, forKey: Self.openOnHoverKey)
    }

    @objc private func grantScreenCapture() {
        IconCapture.requestAccess(openSettingsIfAsked: true)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                // Already registered; registering again would throw.
                // Only the user can approve it.
                SMAppService.openSystemSettingsLoginItems()
            case .notRegistered, .notFound:
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            @unknown default:
                break
            }
        } catch {
            activate()
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Launch at Login"
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func activate() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Accessibility permission

    private func showAccessibilityAlert() {
        activate()
        let alert = NSAlert()
        alert.messageText = "Hairpin needs Accessibility permission"
        alert.informativeText = """
            Hairpin uses the Accessibility API to list the menu bar icons of other apps \
            (including the ones hidden behind the notch) and to open them for you. \
            It does not read window contents or keystrokes.

            Open System Settings › Privacy & Security › Accessibility and turn on Hairpin. \
            If it isn't listed, click + and add Hairpin.app.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            _ = Self.accessibilitySettingsURLs.first { NSWorkspace.shared.open($0) }
        }
    }
}
