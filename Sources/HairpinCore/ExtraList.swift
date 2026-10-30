import Foundation
import CoreGraphics

/// A menu bar extra (status item) of some app, as read via Accessibility.
public struct ExtraItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var pid: Int32
    public var appName: String
    public var bundleID: String?
    public var role: String?
    public var title: String?
    public var detail: String?
    public var help: String?
    /// Global Quartz coordinates (AXPosition + AXSize).
    public var frame: CGRect?

    public init(id: String, pid: Int32, appName: String, bundleID: String? = nil,
                role: String? = nil, title: String? = nil, detail: String? = nil,
                help: String? = nil, frame: CGRect? = nil) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.role = role
        self.title = title
        self.detail = detail
        self.help = help
        self.frame = frame
    }

    public var displayName: String {
        ExtraList.displayName(appName: appName, title: title, detail: detail, help: help)
    }
}

public struct ClassifiedItem: Equatable, Identifiable, Sendable {
    public var item: ExtraItem
    public var visibility: ItemVisibility
    /// A status window drawing the item, if the window list was read: one
    /// that's onscreen if there is one, to capture the item's look from.
    public var windowID: UInt32?
    /// The item's window on the screen it was judged on.
    public var judgedWindowID: UInt32?
    /// Where the item is on the screen it was judged on.
    public var frame: CGRect?
    public var id: String { item.id }

    public init(item: ExtraItem, visibility: ItemVisibility, windowID: UInt32? = nil,
                judgedWindowID: UInt32? = nil, frame: CGRect? = nil) {
        self.item = item
        self.visibility = visibility
        self.windowID = windowID
        self.judgedWindowID = judgedWindowID
        self.frame = frame ?? item.frame
    }
}

public enum ExtraList {
    public static let menuBarItemRole = "AXMenuBarItem"

    /// "App — detail", or just the app name when there's nothing better.
    public static func displayName(appName: String, title: String?, detail: String?, help: String?) -> String {
        let app = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = [title, detail, help]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        switch (app.isEmpty, extra) {
        case (true, nil): return "Unknown"
        case (true, let extra?): return extra
        case (false, nil): return app
        case (false, let extra?):
            return extra.caseInsensitiveCompare(app) == .orderedSame ? app : "\(app) — \(extra)"
        }
    }

    /// Drops our own items, non-menu-bar-item children and duplicate ids.
    public static func filter(_ items: [ExtraItem],
                              excludingPIDs: Set<Int32> = [],
                              excludingBundleIDs: Set<String> = []) -> [ExtraItem] {
        var seen = Set<String>()
        return items.filter { item in
            if excludingPIDs.contains(item.pid) { return false }
            if let bundleID = item.bundleID, excludingBundleIDs.contains(bundleID) { return false }
            if let role = item.role, role != menuBarItemRole { return false }
            return seen.insert(item.id).inserted
        }
    }

    /// Classifies items and orders them by section: hidden, visible, unknown.
    /// Within a section, left-to-right as on the menu bar, then by name.
    ///
    /// With a window list, each item is judged by its copy on the notched
    /// screen (else the primary one), and an item with no status window is
    /// dropped: apps such as Control Center keep zero-sized accessibility
    /// elements for items that aren't in the menu bar at all.
    public static func classifyAndSort(_ items: [ExtraItem], screens: [ScreenInfo],
                                       appMenus: CGRect? = nil,
                                       windows: [StatusWindow]? = nil) -> [ClassifiedItem] {
        classifyAndSort(items, screens: screens, appMenus: appMenus,
                        layout: windows.map { MenuBarLayout(windows: $0, screens: screens) })
    }

    /// The same, with the window list already laid out in rows, and the
    /// items that own each window (see `MenuBarLayout.windowOwners`).
    public static func classifyAndSort(_ items: [ExtraItem], screens: [ScreenInfo], appMenus: CGRect?,
                                       layout: MenuBarLayout?,
                                       owners: [UInt32: String] = [:]) -> [ClassifiedItem] {
        let target = MenuBarLayout.targetScreen(in: screens)
        let owned = Dictionary(grouping: owners.keys) { owners[$0]! }.mapValues(Set.init)
        let named = layout?.windowsByName(for: items, preferring: target) ?? [:]
        var claimed = Set(named.values.map(\.id))
        // Names may come from another display. Reserve the window used for
        // classification too, so a stale position cannot claim its copy.
        for (id, window) in named {
            if let judged = layout?.window(reportedAt: window.frame, owned: owned[id] ?? [], screen: target) {
                claimed.insert(judged.id)
            }
        }
        return items
            .compactMap { item -> ClassifiedItem? in
                guard let layout, let frame = item.frame else {
                    return ClassifiedItem(item: item, visibility: Geometry.visibility(of: item.frame, screens: screens,
                                                                                     appMenus: appMenus))
                }
                guard frame.width > 0, frame.height > 0 else { return nil }
                let reportedAt = named[item.id]?.frame ?? frame
                let copies = layout.copies(of: reportedAt)
                guard let judged = layout.window(reportedAt: reportedAt, owned: owned[item.id] ?? [],
                                                 screen: target) ?? copies.values.first else { return nil }
                // A window named for one app isn't another item's, wherever its frame says.
                if named[item.id] == nil, claimed.contains(judged.id) { return nil }
                let visibility = Geometry.visibility(of: judged.frame, screens: screens, appMenus: appMenus,
                                                     window: judged)
                // Where it's reported, the window is surely its own.
                let reported = layout.reportedWindow(of: reportedAt)?.window
                let drawn = judged.isOnscreen ? judged
                    : reported.flatMap { $0.isOnscreen ? $0 : nil } ?? copies.values.first(where: \.isOnscreen) ?? judged
                return ClassifiedItem(item: item, visibility: visibility, windowID: drawn.id,
                                      judgedWindowID: judged.id, frame: judged.frame)
            }
            .sorted(by: precedes)
    }

    /// Orders items as the menu bar adds them, left to right: apps first, the
    /// most recently launched leftmost (an unknown launch counts as newest),
    /// then Apple's own items on the right. An app's items keep their places.
    public static func inMenuBarOrder(_ items: [ClassifiedItem], launchDates: [Int32: Date]) -> [ClassifiedItem] {
        func isSystem(_ entry: ClassifiedItem) -> Bool { entry.item.bundleID?.hasPrefix("com.apple.") ?? false }
        return items.sorted { a, b in
            let systemA = isSystem(a), systemB = isSystem(b)
            if systemA != systemB { return systemB }
            if !systemA {
                let launchA = launchDates[a.item.pid] ?? .distantFuture
                let launchB = launchDates[b.item.pid] ?? .distantFuture
                if launchA != launchB { return launchA > launchB }
            }
            return (a.frame?.minX ?? .greatestFiniteMagnitude) < (b.frame?.minX ?? .greatestFiniteMagnitude)
        }
    }

    static func precedes(_ a: ClassifiedItem, _ b: ClassifiedItem) -> Bool {
        let sectionA = a.visibility.section
        let sectionB = b.visibility.section
        if sectionA != sectionB { return sectionA < sectionB }
        let xA = a.frame?.minX ?? .greatestFiniteMagnitude
        let xB = b.frame?.minX ?? .greatestFiniteMagnitude
        if xA != xB { return xA < xB }
        let nameOrder = a.item.displayName.localizedCaseInsensitiveCompare(b.item.displayName)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return a.item.id < b.item.id
    }
}
