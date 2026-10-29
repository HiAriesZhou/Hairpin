import Foundation
import CoreGraphics

/// A status item window as the window server lists it (`CGWindowListCopyWindowInfo`
/// at the status window level), in global Quartz coordinates.
public struct StatusWindow: Equatable, Sendable {
    public var id: UInt32
    public var frame: CGRect
    /// False when the window server keeps the window out of the menu bar. On
    /// macOS 26 that's how overflowed items are hidden: the window stays in the
    /// row but isn't drawn.
    public var isOnscreen: Bool
    /// The window title. With Screen Recording permission, macOS 26 names the
    /// status windows on the active menu bar after the owning app's bundle ID,
    /// or its PID when it has none.
    public var name: String?

    public init(id: UInt32, frame: CGRect, isOnscreen: Bool, name: String? = nil) {
        self.id = id
        self.frame = frame
        self.isOnscreen = isOnscreen
        self.name = name
    }
}

/// The status windows of every menu bar, one row per screen.
///
/// Every screen's menu bar shows the same items in the same order, laid out
/// from its right edge, so the nth window from the right is the same item on
/// every screen. Accessibility reports an item's frame on whichever screen it
/// likes; the rows find that item's copy on the others.
public struct MenuBarLayout {
    /// Taller windows at the status level aren't menu bar items.
    static let maximumItemHeight: CGFloat = 50
    /// How far above its screen a hidden menu bar parks its row.
    static let maximumRowOffset: CGFloat = 100

    /// Windows per screen index, right to left.
    let rows: [Int: [StatusWindow]]
    private let screens: [ScreenInfo]

    public init(windows: [StatusWindow], screens: [ScreenInfo]) {
        var byScreen: [Int: [StatusWindow]] = [:]
        for window in windows where window.frame.height <= Self.maximumItemHeight {
            guard let screen = Self.screen(of: window.frame, in: screens) else { continue }
            byScreen[screen, default: []].append(window)
        }
        rows = byScreen.mapValues { windows in
            // A row moving between two heights shows up twice; keep the fuller one.
            let levels = Dictionary(grouping: windows) { $0.frame.minY.rounded() }
            let row = levels.values.max { $0.count < $1.count } ?? []
            return row.sorted { $0.frame.maxX > $1.frame.maxX }
        }
        self.screens = screens
    }

    /// The status windows in a screen's menu bar, right to left.
    public func row(_ screen: Int) -> [StatusWindow] {
        rows[screen] ?? []
    }

    /// The windows of every row; status-level windows that aren't menu bar
    /// items are left out.
    public var allRows: [StatusWindow] {
        rows.values.flatMap { $0 }
    }

    /// The screen whose menu bar items are judged: the notched one, else the
    /// primary one.
    public static func targetScreen(in screens: [ScreenInfo]) -> Int {
        screens.firstIndex { $0.notch != nil } ?? 0
    }

    /// Whether a screen's menu bar is showing: its row sits at the top of the
    /// screen rather than parked above it (auto-hide, full screen).
    public func isShowing(_ screen: Int) -> Bool {
        guard screens.indices.contains(screen), let window = row(screen).first else { return false }
        return abs(window.frame.minY - screens[screen].frame.minY) <= 2
    }

    /// Where the pin holding the hidden items goes in a screen's menu bar, at
    /// the left end of the items shown there; nil while that menu bar isn't
    /// showing, or when there's no room and nothing it may sit on.
    ///
    /// Hairpin's own icon (`own`) holds them when its copy in this menu bar
    /// is the leftmost shown item; `own` may be reported in another screen's
    /// menu bar. Otherwise the pin, `width` wide, takes the first free slot (see
    /// `Geometry.stackSlot`); failing that, it sits on the leftmost shown
    /// window in `coverable` (windows of known items, which are then listed
    /// with the hidden ones). Shown means drawn where it can be seen: before
    /// macOS 26 an overflowed window is still drawn, under the notch.
    public func placement(width: CGFloat, screen: Int, appMenus: CGRect?, own: CGRect?,
                          coverable: Set<UInt32>) -> StackPlacement? {
        guard isShowing(screen) else { return nil }
        let shown = row(screen).filter { window in
            Geometry.visibility(of: window.frame, screens: screens, appMenus: appMenus, window: window) == .visible
        }
        guard let leftmost = shown.last else { return nil }
        if let own, copies(of: own)[screen]?.id == leftmost.id { return .ownIcon(leftmost) }
        if let edge = Geometry.stackSlot(width: width, screens: screens, screen: screen, appMenus: appMenus,
                                         leftmostShown: leftmost.frame, margin: 2) {
            return .slot(rightEdge: edge)
        }
        return shown.reversed().first { coverable.contains($0.id) }.map(StackPlacement.covering)
    }

    /// Each item's window, found by the window names rather than by position:
    /// Accessibility can keep reporting where an item was before the row was
    /// relaid out. Only the active menu bar names its windows after apps
    /// (others use autosave names), so every row is tried, `screen`'s first.
    /// An app's items pair with its windows in order from the right; an app
    /// whose counts differ in every row is left out.
    public func windowsByName(for items: [ExtraItem], preferring screen: Int) -> [String: StatusWindow] {
        let order = [screen] + rows.keys.filter { $0 != screen }.sorted()
        let shown = items.filter { ($0.frame?.width ?? 0) > 0 && ($0.frame?.height ?? 0) > 0 }
        var result: [String: StatusWindow] = [:]
        for (pid, appItems) in Dictionary(grouping: shown, by: \.pid) {
            let names = Set([String(pid)] + appItems.compactMap(\.bundleID))
            guard let appWindows = order.lazy
                .map({ self.row($0).filter { $0.name.map(names.contains) ?? false } })
                .first(where: { $0.count == appItems.count }) else { continue }
            let ordered = appItems.sorted { $0.frame!.maxX > $1.frame!.maxX }
            for (item, window) in zip(ordered, appWindows) { result[item.id] = window }
        }
        return result
    }

    /// The copies of the item whose button is at `frame`, by screen index.
    ///
    /// On another screen the copy is the window of the same width nearest the
    /// same place from the right: an overflowing row can fit a narrower item
    /// into a gap a wider one skipped, swapping the two.
    public func copies(of frame: CGRect) -> [Int: StatusWindow] {
        guard let (row, rank) = locate(frame) else { return [:] }
        let width = rows[row]![rank].frame.width
        return rows.compactMapValues { windows in
            windows.indices
                .filter { abs(windows[$0].frame.width - width) <= 1 }
                .min { abs($0 - rank) < abs($1 - rank) }
                .map { windows[$0] }
        }
    }

    /// The row and place of the window holding the button: the one it mostly
    /// overlaps, as Accessibility can lag a relayout by a few points.
    private func locate(_ frame: CGRect) -> (row: Int, rank: Int)? {
        for (row, windows) in rows {
            if let rank = Self.place(of: frame, in: windows, sameLevel: true) { return (row, rank) }
        }
        // It can also lag behind a row that moved (a menu bar parking or coming
        // back); the screen's row keeps the item's horizontal place.
        guard let row = Self.screen(of: frame, in: screens), let windows = rows[row],
              let rank = Self.place(of: frame, in: windows, sameLevel: false) else { return nil }
        return (row, rank)
    }

    private static func place(of frame: CGRect, in windows: [StatusWindow], sameLevel: Bool) -> Int? {
        let overlaps = windows.indices.compactMap { index -> (index: Int, overlap: CGFloat)? in
            let window = windows[index].frame
            if sameLevel && !(window.minY < frame.maxY && frame.minY < window.maxY) { return nil }
            let overlap = min(window.maxX, frame.maxX) - max(window.minX, frame.minX)
            return overlap >= min(window.width, frame.width) / 2 ? (index, overlap) : nil
        }
        return overlaps.max { $0.overlap < $1.overlap }?.index
    }

    /// The screen whose menu bar a rect is in: across its width, nearest its top
    /// edge, and no further above it than a parked row.
    private static func screen(of rect: CGRect, in screens: [ScreenInfo]) -> Int? {
        screens.indices
            .filter { screens[$0].frame.minX <= rect.midX && rect.midX <= screens[$0].frame.maxX }
            .map { (index: $0, distance: abs(rect.minY - screens[$0].frame.minY)) }
            .filter { $0.distance <= maximumRowOffset }
            .min { $0.distance < $1.distance }?
            .index
    }
}

/// Where the pin holding the hidden items goes; see `MenuBarLayout.placement`.
public enum StackPlacement: Equatable, Sendable {
    /// Hairpin's own icon, in this window, is the leftmost shown item and
    /// holds them.
    case ownIcon(StatusWindow)
    /// A free slot ending at this x (Quartz).
    case slot(rightEdge: CGFloat)
    /// On this shown item's window, for lack of room.
    case covering(StatusWindow)
}
