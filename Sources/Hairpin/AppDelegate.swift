import AppKit
import ApplicationServices
import HairpinCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var isMenuOpen = false

    /// The latest finished scan. The menu is built only from this, so opening
    /// it never waits on another app; nil until the first scan finishes.
    private var entries: [ClassifiedItem]?
    /// The extras behind `entries`, by item id.
    private var extras: [String: LiveExtra] = [:]
    private var isScanning = false
    private var scanAgain = false
    private let scanQueue = DispatchQueue(label: "com.hiarieszhou.hairpin.scan", qos: .userInitiated)

    private static let autosaveName = "Hairpin"
    /// The macOS 13+ Privacy & Security pane first, the legacy pane id second.
    private static let accessibilitySettingsURLs = [
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!,
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestRightmostPosition()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = Self.autosaveName
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "menubar.arrow.up.rectangle", accessibilityDescription: "Hairpin")
                ?? NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Hairpin")
            if let image {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⋯"
            }
            button.toolTip = "Hairpin"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        // Keep the snapshot fresh so the menu rarely has to update while open.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
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
    /// shows the list at the pointer: a way in if our own icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task {
            _ = self.menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
        return false
    }

    /// Overflowing status items are dropped from the left end of the row, so
    /// the slot next to the system items is the last to go behind the notch.
    /// On first launch, ask for it through the undocumented default AppKit
    /// keeps ⌘-drag positions in (distance from the right edge). Once the
    /// user moves the icon, their choice is stored there and wins.
    private func requestRightmostPosition() {
        let key = "NSStatusItem Preferred Position \(Self.autosaveName)"
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        UserDefaults.standard.set(0.0, forKey: key)
    }

    // MARK: - Scanning

    @objc private func environmentChanged(_ notification: Notification) {
        refresh()
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
        let sorted = ExtraList.classifyAndSort(items, screens: Screens.current(), appMenus: scan.appMenus)
        let changed = sorted != entries
        entries = sorted
        extras = Dictionary(scan.extras.map { ($0.item.id, $0) }, uniquingKeysWith: { first, _ in first })
        // An open menu updates in place.
        if changed && isMenuOpen { rebuild(menu) }
        if scanAgain {
            scanAgain = false
            refresh()
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        refresh()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        if MenuBarExtras.isTrusted {
            addExtras(to: menu)
        } else {
            let grant = NSMenuItem(title: "Grant Accessibility…", action: #selector(grantAccessibility), keyEquivalent: "")
            grant.target = self
            grant.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)
            menu.addItem(grant)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
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

    private func addExtras(to menu: NSMenu) {
        guard let entries else {
            menu.addItem(header("Reading menu bar items…"))
            return
        }
        guard !entries.isEmpty else {
            menu.addItem(header("No menu bar items found"))
            return
        }

        var icons: [pid_t: NSImage] = [:]
        var lastSection: ItemSection?
        for entry in entries {
            let section = entry.visibility.section
            if section != lastSection {
                if lastSection != nil { menu.addItem(.separator()) }
                menu.addItem(header(Self.title(of: section)))
                lastSection = section
            }
            let menuItem = NSMenuItem(title: entry.item.displayName, action: #selector(openExtra(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = entry.item.id
            menuItem.toolTip = entry.item.bundleID
            menuItem.indentationLevel = 1
            if icons[entry.item.pid] == nil { icons[entry.item.pid] = icon(for: entry.item.pid) }
            menuItem.image = icons[entry.item.pid]
            menu.addItem(menuItem)
        }
    }

    private static func title(of section: ItemSection) -> String {
        switch section {
        case .hidden: return "Hidden by the notch"
        case .visible: return "Visible"
        case .unknown: return "Position unknown"
        }
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func icon(for pid: pid_t) -> NSImage? {
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon?.copy() as? NSImage else { return nil }
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    // MARK: - Actions

    @objc private func openExtra(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let extra = extras[id] else { return }
        // Let our own menu finish closing, then press off the main thread:
        // AXPress blocks while the target app opens its menu.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            MenuBarExtras.open(extra)
        }
    }

    @objc private func grantAccessibility() {
        showAccessibilityAlert()
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
