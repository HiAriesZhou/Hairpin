import Foundation

/// A menu bar extra (status item) of some app, as read via Accessibility.
public struct ExtraItem: Equatable, Identifiable {
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

public struct ClassifiedItem: Equatable, Identifiable {
    public var item: ExtraItem
    public var visibility: ItemVisibility
    public var id: String { item.id }
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

    /// Classifies items and orders them: hidden first, then visible, then
    /// unknown. Within a group, left-to-right as on the menu bar, then by name.
    public static func classifyAndSort(_ items: [ExtraItem], screens: [ScreenInfo]) -> [ClassifiedItem] {
        items
            .map { ClassifiedItem(item: $0, visibility: Geometry.visibility(of: $0.frame, screens: screens)) }
            .sorted(by: precedes)
    }

    static func precedes(_ a: ClassifiedItem, _ b: ClassifiedItem) -> Bool {
        let groupA = a.visibility.isHidden ? 0 : (a.visibility == .visible ? 1 : 2)
        let groupB = b.visibility.isHidden ? 0 : (b.visibility == .visible ? 1 : 2)
        if groupA != groupB { return groupA < groupB }
        let xA = a.item.frame?.minX ?? .greatestFiniteMagnitude
        let xB = b.item.frame?.minX ?? .greatestFiniteMagnitude
        if xA != xB { return xA < xB }
        let nameOrder = a.item.displayName.localizedCaseInsensitiveCompare(b.item.displayName)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return a.item.id < b.item.id
    }
}
