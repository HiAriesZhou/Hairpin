import AppKit
import ApplicationServices
import NotchBarCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    /// Elements behind the entries of the currently built menu, by item id.
    private var elements: [String: AXUIElement] = [:]

    private static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "menubar.arrow.up.rectangle", accessibilityDescription: "NotchBar")
                ?? NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "NotchBar")
            if let image {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⋯"
            }
            button.toolTip = "NotchBar"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        if !MenuBarExtras.isTrusted {
            // The menu is rebuilt on every open, so it picks up the grant by itself.
            showAccessibilityAlert()
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        elements = [:]

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
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let quitItem = NSMenuItem(title: "Quit NotchBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addExtras(to menu: NSMenu) {
        let live = MenuBarExtras.all()
        let ownBundleID = Bundle.main.bundleIdentifier.map { Set([$0]) } ?? []
        let items = ExtraList.filter(live.map(\.item),
                                     excludingPIDs: [ProcessInfo.processInfo.processIdentifier],
                                     excludingBundleIDs: ownBundleID)
        let sorted = ExtraList.classifyAndSort(items, screens: Screens.current())
        for extra in live { elements[extra.item.id] = extra.element }

        guard !sorted.isEmpty else {
            menu.addItem(header("No menu bar items found"))
            return
        }

        var icons: [pid_t: NSImage] = [:]
        var lastHidden: Bool?
        for entry in sorted {
            let hidden = entry.visibility.isHidden
            if hidden != lastHidden {
                if lastHidden != nil { menu.addItem(.separator()) }
                menu.addItem(header(hidden ? "Hidden by the notch" : "Visible"))
                lastHidden = hidden
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
        guard let id = sender.representedObject as? String, let element = elements[id] else { return }
        // Let our own menu finish closing, then press off the main thread:
        // AXPress blocks while the target app opens its menu.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            MenuBarExtras.open(element)
        }
    }

    @objc private func grantAccessibility() {
        showAccessibilityAlert()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Launch at Login"
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Accessibility permission

    private func showAccessibilityAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "NotchBar needs Accessibility permission"
        alert.informativeText = """
            NotchBar uses the Accessibility API to list the menu bar icons of other apps \
            (including the ones hidden behind the notch) and to open them for you. \
            It does not read window contents or keystrokes.

            Open System Settings › Privacy & Security › Accessibility and turn on NotchBar. \
            If it isn't listed, click + and add NotchBar.app.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(Self.accessibilitySettingsURL)
        }
    }
}
