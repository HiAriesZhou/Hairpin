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
    private let looks = ItemLooks()
    /// Where the stack goes, from the latest scan.
    private var anchor: StackAnchor?
    /// The item each status window belongs to, and our icon's windows: while
    /// another menu bar is active, items are reported in that one, whose
    /// order the notched one doesn't keep (see `MenuBarLayout.windowOwners`).
    private var windowOwners: [UInt32: String] = [:]
    private var ownWindows: Set<UInt32> = []
    private var lastProbe = Date.distantPast
    private var failedProbes = 0
    private var isScanning = false
    private var scanAgain = false
    /// The menu bar rows' windows as last seen, which a cheap poll compares
    /// against: apps add, drop and resize menu bar items, and menu bars hide
    /// and show, without any notification.
    private var windowStates: [WindowState] = []
    private var menuBarWatch: Timer?
    /// The latest Accessibility scan, replayed against fresh window lists.
    private var lastScan: MenuBarExtras.Scan?
    private var lastWatchScan = Date.distantPast
    private var watchScanPending = false
    private var appearanceObservation: NSKeyValueObservation?
    private let scanQueue = DispatchQueue(label: "com.hiarieszhou.hairpin.scan", qos: .userInitiated)

    private static let autosaveName = "Hairpin"
    private static let menusSettleDelay: TimeInterval = 0.4
    private static let menuBarWatchInterval: TimeInterval = 0.5
    /// The fewest seconds between Accessibility scans the watch starts.
    private static let watchScanInterval: TimeInterval = 2
    /// How much wider our icon briefly gets to find its windows, for how
    /// long, and the fewest seconds between two tries, doubling after each
    /// that finds nothing, up to the longest.
    private static let probeGrowth: CGFloat = 2
    private static let probeDuration: Duration = .milliseconds(250)
    private static let probeInterval: TimeInterval = 5
    private static let longestProbeInterval: TimeInterval = 300
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
        menuBarWatch = Timer.scheduledTimer(withTimeInterval: Self.menuBarWatchInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkMenuBar() }
        }
        menuBarWatch?.tolerance = Self.menuBarWatchInterval / 2
        // The pin follows the menu bar between light and dark.
        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateStack() }
        }

        if MenuBarExtras.isTrusted {
            refresh()
        } else {
            // The menu is rebuilt on every open, so it picks up the grant by itself.
            showAccessibilityAlert()
        }
    }

    /// Opening Hairpin.app again (Finder, Spotlight, Launchpad) while it runs
    /// opens the hidden items, under the pin or, with no pin showing, at the
    /// pointer; with none hidden it shows the menu at the pointer. A way in
    /// when our icon is out of sight.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task {
            let opened = self.hidden?.isEmpty == false
                && (self.stack.expand(pinned: true) || self.stack.expandAtPointer())
            if !opened { _ = self.menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil) }
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
        guard MenuBarExtras.isTrusted else {
            // Without access the snapshot goes stale; don't leave the pin
            // behind, and start over once access is back.
            windowStates = []
            lastScan = nil
            if hidden != nil {
                hidden = nil
                anchor = nil
                extras = [:]
                updateStack()
            }
            return
        }
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
        lastScan = scan
        apply(scan, remembering: true)
        if scanAgain {
            scanAgain = false
            refresh()
        }
    }

    /// Works out what's hidden and where the pin goes from a scan's items and
    /// window list, then redraws. Windows' owners are learned only from a
    /// fresh scan; a replay's item frames predate its windows.
    private func apply(_ scan: MenuBarExtras.Scan, remembering: Bool = false) {
        let ownBundleID = Bundle.main.bundleIdentifier.map { Set([$0]) } ?? []
        let items = ExtraList.filter(scan.extras.map(\.item),
                                     excludingPIDs: [ProcessInfo.processInfo.processIdentifier],
                                     excludingBundleIDs: ownBundleID)
        let screens = Screens.current()
        let layout = scan.windows.isEmpty ? nil : MenuBarLayout(windows: scan.windows, screens: screens)
        let ownFrame = (statusItem.button?.window?.frame).map { frame in
            Geometry.quartzRect(fromCocoa: frame, primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0)
        }
        if let layout {
            ownWindows = ownWindows.intersection(scan.windows.map(\.id))
            let target = MenuBarLayout.targetScreen(in: screens)
            if !layout.row(target).contains(where: { ownWindows.contains($0.id) }) { probeOwnWindows() }
        }
        // Other items are matched without our windows: our icon sits right of
        // the hidden items in the notched menu bar but left of them in the
        // others, and left out, the rows line up.
        let itemLayout = layout.map { _ in
            MenuBarLayout(windows: scan.windows.filter { !ownWindows.contains($0.id) }, screens: screens)
        }
        if remembering, let itemLayout {
            windowOwners = itemLayout.windowOwners(for: items, keeping: windowOwners)
        }
        let sorted = ExtraList.classifyAndSort(items, screens: screens, appMenus: scan.appMenus, layout: itemLayout,
                                               owners: windowOwners)
        logScan(items: items, sorted: sorted, windows: scan.windows)
        kept = sorted
        windowStates = layout.map(WindowState.of) ?? []
        let shown = sorted.filter { !$0.visibility.isHidden }
        // With nothing hidden there's no pin; it mustn't cover an item and so
        // hide one itself.
        anchor = shown.count == sorted.count ? nil : layout.flatMap { layout in
            Screens.stackAnchor(layout: layout, screens: screens, appMenus: scan.appMenus, own: ownFrame,
                                ownWindows: ownWindows, coverable: Set(shown.compactMap(\.judgedWindowID)))
        }
        // The item under the pin, if it had to sit on one, is kept with the hidden ones.
        let covered = anchor?.covered.flatMap { window in shown.first { $0.judgedWindowID == window } }
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
        looks.forget(exceptWindows: Set(scan.windows.map(\.id)),
                     pids: Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier)))
        updateStack()
        looks.capture(from: sorted) { [weak self] in self?.updateStack() }
    }

    /// Finds our icon's windows, its copy in every menu bar: once a menu bar
    /// overflows, nothing else tells them from another app's. The icon gets a
    /// little wider for a moment, and the windows that grew are ours. It sits
    /// at the left end, mostly beside hidden items, so the nudge goes unseen;
    /// it's done only while our windows aren't known (at launch, and after
    /// macOS makes new ones).
    private func probeOwnWindows() {
        let wait = min(Self.probeInterval * pow(2, Double(failedProbes)), Self.longestProbeInterval)
        guard Date().timeIntervalSince(lastProbe) >= wait,
              let width = statusItem.button?.frame.width, width > 0 else { return }
        lastProbe = Date()
        let before = MenuBarExtras.statusWindows()
        statusItem.length = width + Self.probeGrowth
        Task {
            try? await Task.sleep(for: Self.probeDuration)
            let after = MenuBarExtras.statusWindows()
            self.statusItem.length = NSStatusItem.squareLength
            let grown = MenuBarLayout.grownWindows(from: before, to: after, by: Self.probeGrowth,
                                                   screens: Screens.current())
            log.debug("own windows: \(grown.sorted().map(String.init).joined(separator: ","), privacy: .public)")
            guard !grown.isEmpty else {
                self.failedProbes += 1
                return
            }
            self.failedProbes = 0
            self.ownWindows = grown
            if let scan = self.lastScan, !self.isScanning {
                self.apply(MenuBarExtras.Scan(extras: scan.extras, appMenus: scan.appMenus,
                                              windows: MenuBarExtras.statusWindows()))
            }
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

    /// Follows the menu bar rows between scans. When their windows moved or
    /// changed whether they're drawn (a menu bar hiding or showing, an item
    /// overflowing), the last scan's items are replayed against the fresh
    /// window list right away. When windows came or went (an item added or
    /// dropped), a new Accessibility scan finds out what they are, at most
    /// every couple of seconds. The window list is cheap; the scan isn't.
    private func checkMenuBar() {
        guard MenuBarExtras.isTrusted else {
            if hidden != nil || !windowStates.isEmpty { refresh() }
            return
        }
        guard !isScanning else { return }
        scanQueue.async {
            let windows = MenuBarExtras.statusWindows()
            Task { @MainActor in self.compare(windows) }
        }
    }

    private func compare(_ windows: [StatusWindow]) {
        let states = WindowState.of(MenuBarLayout(windows: windows, screens: Screens.current()))
        guard states != windowStates, !isScanning else { return }
        let sameWindows = Set(states.map(\.id)) == Set(windowStates.map(\.id))
        if let scan = lastScan {
            apply(MenuBarExtras.Scan(extras: scan.extras, appMenus: scan.appMenus, windows: windows))
        }
        if !sameWindows { scheduleWatchScan() }
    }

    /// Scans as soon as the last scan the watch started is a couple of
    /// seconds old; one waiting scan covers every change until it runs.
    private func scheduleWatchScan() {
        guard !watchScanPending else { return }
        watchScanPending = true
        let wait = max(0, Self.watchScanInterval - Date().timeIntervalSince(lastWatchScan))
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self else { return }
            self.watchScanPending = false
            self.lastWatchScan = Date()
            self.refresh()
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
            looks.image(for: entry).map { StackEntry(id: entry.item.id, image: $0, toolTip: entry.item.displayName) }
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
            menu.addItem(action("Grant Accessibility…", #selector(grantAccessibility)))
        } else {
            menu.addItem(header(Self.status(hiddenCount: hidden?.count)))
            if #available(macOS 14, *), !IconCapture.isAvailable {
                menu.addItem(action("Show Real Icons…", #selector(grantScreenCapture)))
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

    /// No images: macOS 26 indents a menu section's titles past an image
    /// column when any of its items has one, so the sections wouldn't line up.
    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
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

/// A menu bar row window as the watch compares it: where it is and whether
/// it's drawn, not what it's named (names follow the active menu bar).
private struct WindowState: Equatable {
    let id: UInt32
    let frame: CGRect
    let isOnscreen: Bool

    /// The windows of every menu bar row, leaving out other windows at the
    /// status level (floating panels and the like).
    static func of(_ layout: MenuBarLayout) -> [WindowState] {
        layout.allRows
            .map { WindowState(id: $0.id, frame: $0.frame, isOnscreen: $0.isOnscreen) }
            .sorted { $0.id < $1.id }
    }
}
