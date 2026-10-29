import Foundation
import CoreGraphics
import XCTest
@testable import HairpinCore

/// 14" MacBook Pro at default scaling: 1512×982 points, 204-pt-wide notch.
private let builtInCocoa = CGRect(x: 0, y: 0, width: 1512, height: 982)
private let leftArea = CGRect(x: 0, y: 950, width: 654, height: 32)
private let rightArea = CGRect(x: 858, y: 950, width: 654, height: 32)
private let notchQuartz = CGRect(x: 654, y: 0, width: 204, height: 32)
private let builtIn = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), notch: notchQuartz)

private func item(_ id: String, x: CGFloat?, width: CGFloat = 24, pid: Int32 = 100,
                  app: String = "App", title: String? = nil, role: String? = "AXMenuBarItem") -> ExtraItem {
    ExtraItem(id: id, pid: pid, appName: app, role: role, title: title,
              frame: x.map { CGRect(x: $0, y: 0, width: width, height: 32) })
}

final class GeometryTests: XCTestCase {
    func testQuartzConversionFlipsAroundPrimaryHeight() {
        let cocoa = CGRect(x: 10, y: 950, width: 20, height: 32)
        XCTAssertEqual(Geometry.quartzRect(fromCocoa: cocoa, primaryScreenHeight: 982),
                       CGRect(x: 10, y: 0, width: 20, height: 32))
    }

    func testQuartzConversionForScreenAbovePrimary() {
        let external = CGRect(x: -200, y: 982, width: 1920, height: 1080)
        XCTAssertEqual(Geometry.quartzRect(fromCocoa: external, primaryScreenHeight: 982),
                       CGRect(x: -200, y: -1080, width: 1920, height: 1080))
    }

    func testNotchRectFromGlobalAreas() {
        XCTAssertEqual(Geometry.notchRect(screenFrame: builtInCocoa, topLeftArea: leftArea, topRightArea: rightArea),
                       CGRect(x: 654, y: 950, width: 204, height: 32))
    }

    func testNotchRectFromLocalAreasOnSecondaryScreen() {
        let screen = CGRect(x: 1920, y: -300, width: 1512, height: 982)
        XCTAssertEqual(Geometry.notchRect(screenFrame: screen, topLeftArea: leftArea, topRightArea: rightArea),
                       CGRect(x: 1920 + 654, y: -300 + 950, width: 204, height: 32))
    }

    func testNotchRectFromGlobalAreasOnSecondaryScreen() {
        let screen = CGRect(x: 1920, y: -300, width: 1512, height: 982)
        let l = leftArea.offsetBy(dx: 1920, dy: -300)
        let r = rightArea.offsetBy(dx: 1920, dy: -300)
        XCTAssertEqual(Geometry.notchRect(screenFrame: screen, topLeftArea: l, topRightArea: r),
                       CGRect(x: 1920 + 654, y: -300 + 950, width: 204, height: 32))
    }

    func testNoNotchWithoutAuxiliaryAreas() {
        XCTAssertNil(Geometry.notchRect(screenFrame: builtInCocoa, topLeftArea: nil, topRightArea: nil))
        XCTAssertNil(Geometry.notchRect(screenFrame: builtInCocoa, topLeftArea: leftArea, topRightArea: nil))
        XCTAssertNil(Geometry.notchRect(screenFrame: builtInCocoa, topLeftArea: .zero, topRightArea: rightArea))
    }

    func testNoNotchWhenAreasTouch() {
        let l = CGRect(x: 0, y: 950, width: 756, height: 32)
        let r = CGRect(x: 756, y: 950, width: 756, height: 32)
        XCTAssertNil(Geometry.notchRect(screenFrame: builtInCocoa, topLeftArea: l, topRightArea: r))
    }

    func testVisibleItemRightOfNotch() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 1200, y: 0, width: 24, height: 32), screens: [builtIn]), .visible)
    }

    func testItemFlushAgainstNotchIsVisible() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 858, y: 0, width: 24, height: 32), screens: [builtIn]), .visible)
    }

    func testItemOverlappingNotchIsHidden() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 845, y: 0, width: 24, height: 32), screens: [builtIn]), .hiddenByNotch)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 700, y: 0, width: 24, height: 32), screens: [builtIn]), .hiddenByNotch)
    }

    func testItemLeftOfNotchIsHiddenWhenAppMenusAreUnknown() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 400, y: 0, width: 24, height: 32), screens: [builtIn]), .hiddenByNotch)
    }

    func testItemLeftOfNotchPastShortAppMenusIsVisible() {
        let menus = CGRect(x: 0, y: 0, width: 300, height: 32)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 400, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .visible)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 300, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .visible)
    }

    func testItemLeftOfNotchCoveredByAppMenusIsHidden() {
        let menus = CGRect(x: 0, y: 0, width: 300, height: 32)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 250, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .hiddenByNotch)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 290, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .hiddenByNotch)
    }

    func testShortAppMenusDontUncoverTheNotch() {
        let menus = CGRect(x: 0, y: 0, width: 300, height: 32)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 700, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .hiddenByNotch)
    }

    func testAppMenusPastTheNotchCoverEverythingLeftOfIt() {
        let menus = CGRect(x: 0, y: 0, width: 1000, height: 32)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 600, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .hiddenByNotch)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 1200, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .visible)
    }

    func testAppMenusReadOnAnotherScreenKeepTheirWidth() {
        let external = ScreenInfo(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let menus = CGRect(x: -1920, y: 0, width: 300, height: 24)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 400, y: 0, width: 24, height: 32), screens: [external, builtIn],
                                           appMenus: menus), .visible)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 250, y: 0, width: 24, height: 32), screens: [external, builtIn],
                                           appMenus: menus), .hiddenByNotch)
    }

    func testAppMenusOffEveryScreenCountAsUnknown() {
        let menus = CGRect(x: 5000, y: 0, width: 300, height: 32)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 400, y: 0, width: 24, height: 32), screens: [builtIn],
                                           appMenus: menus), .hiddenByNotch)
    }

    func testLeftOfCenterIsVisibleWithoutNotch() {
        let plain = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 400, y: 0, width: 24, height: 32), screens: [plain]), .visible)
    }

    func testNotchOnlyAffectsItsOwnScreen() {
        let external = ScreenInfo(frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080))
        let onExternal = CGRect(x: 1512 + 400, y: 0, width: 24, height: 24)
        XCTAssertEqual(Geometry.visibility(of: onExternal, screens: [builtIn, external]), .visible)
    }

    func testOffscreenItem() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: -100, y: 0, width: 24, height: 32), screens: [builtIn]), .offscreen)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 1505, y: 0, width: 24, height: 32), screens: [builtIn]), .offscreen)
    }

    func testMostlyOnscreenItemIsVisible() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 1495, y: 0, width: 24, height: 32), screens: [builtIn]), .visible)
    }

    func testZeroSizedItemIsOffscreen() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 1200, y: 0, width: 0, height: 32), screens: [builtIn]), .offscreen)
    }

    func testMissingFrameIsUnknown() {
        XCTAssertEqual(Geometry.visibility(of: nil, screens: [builtIn]), .unknown)
        XCTAssertFalse(ItemVisibility.unknown.isHidden)
        XCTAssertTrue(ItemVisibility.offscreen.isHidden)
        XCTAssertTrue(ItemVisibility.hiddenByNotch.isHidden)
    }

    func testSections() {
        XCTAssertEqual(ItemVisibility.hiddenByNotch.section, .hidden)
        XCTAssertEqual(ItemVisibility.offscreen.section, .hidden)
        XCTAssertEqual(ItemVisibility.visible.section, .visible)
        XCTAssertEqual(ItemVisibility.unknown.section, .unknown)
        XCTAssertLessThan(ItemSection.hidden, .visible)
        XCTAssertLessThan(ItemSection.visible, .unknown)
    }
}

final class ExtraListTests: XCTestCase {
    func testDisplayName() {
        XCTAssertEqual(ExtraList.displayName(appName: "Dropbox", title: nil, detail: nil, help: nil), "Dropbox")
        XCTAssertEqual(ExtraList.displayName(appName: "Control Center", title: " ", detail: "Wi‑Fi", help: "x"),
                       "Control Center — Wi‑Fi")
        XCTAssertEqual(ExtraList.displayName(appName: "Bartender", title: "bartender", detail: nil, help: nil), "Bartender")
        XCTAssertEqual(ExtraList.displayName(appName: "", title: nil, detail: nil, help: "Clock"), "Clock")
        XCTAssertEqual(ExtraList.displayName(appName: "  ", title: nil, detail: nil, help: nil), "Unknown")
    }

    func testFilterDropsOwnItemsOtherRolesAndDuplicates() {
        var ours = item("ours", x: 1300, pid: 1)
        ours.bundleID = "com.hiarieszhou.hairpin"
        var otherBundle = item("bundle", x: 1300, pid: 3)
        otherBundle.bundleID = "com.example.hidden"
        let items = [
            item("a", x: 1200, pid: 2),
            ours,
            otherBundle,
            item("menu", x: 1210, pid: 2, role: "AXMenu"),
            item("noRole", x: 1220, pid: 2, role: nil),
            item("a", x: 1200, pid: 2),
        ]
        let kept = ExtraList.filter(items, excludingPIDs: [1], excludingBundleIDs: ["com.example.hidden"])
        XCTAssertEqual(kept.map(\.id), ["a", "noRole"])
    }

    func testSortPutsHiddenFirstThenVisibleThenUnknown() {
        let items = [
            item("unknown", x: nil, app: "Zed"),
            item("visible2", x: 1400),
            item("underNotch", x: 800),
            item("visible1", x: 1000),
            item("leftOfNotch", x: 500),
            item("offscreen", x: -50),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn])
        XCTAssertEqual(sorted.map(\.id), ["offscreen", "leftOfNotch", "underNotch", "visible1", "visible2", "unknown"])
        XCTAssertEqual(sorted.map(\.visibility), [.offscreen, .hiddenByNotch, .hiddenByNotch, .visible, .visible, .unknown])
    }

    func testSortUsesAppMenusLeftOfNotch() {
        let items = [
            item("visible", x: 1000),
            item("gap", x: 500),
            item("covered", x: 100),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn], appMenus: CGRect(x: 0, y: 0, width: 300, height: 32))
        XCTAssertEqual(sorted.map(\.id), ["covered", "gap", "visible"])
        XCTAssertEqual(sorted.map(\.visibility.section), [.hidden, .visible, .visible])
    }

    func testSortTieBreaksByNameThenID() {
        let items = [
            item("3", x: nil, app: "beta"),
            item("2", x: nil, app: "Alpha"),
            item("1", x: nil, app: "alpha"),
        ]
        XCTAssertEqual(ExtraList.classifyAndSort(items, screens: [builtIn]).map(\.id), ["1", "2", "3"])
    }
}

/// Status windows are a few points wider and taller than the button that
/// Accessibility reports: `window(x:)` draws the item at `item(x:)`.
private func window(_ id: UInt32, x: CGFloat, width: CGFloat = 24, y: CGFloat = 0, onscreen: Bool = true) -> StatusWindow {
    StatusWindow(id: id, frame: CGRect(x: x - 3, y: y, width: width + 6, height: 33), isOnscreen: onscreen)
}

/// An external display above the built-in one, whose menu bar row repeats the
/// built-in row against its own right edge.
private let external = ScreenInfo(frame: CGRect(x: -216, y: -1080, width: 1920, height: 1080))

final class MenuBarLayoutTests: XCTestCase {
    func testCopiesFindTheWindowAroundTheButton() {
        let layout = MenuBarLayout(windows: [window(1, x: 1000), window(2, x: 1200), window(3, x: 1300)],
                                   screens: [builtIn])
        XCTAssertEqual(layout.copies(of: CGRect(x: 1200, y: 4.5, width: 24, height: 24)).mapValues(\.id), [0: 2])
    }

    func testCopiesIgnoreWindowsThatDontHoldTheButton() {
        let layout = MenuBarLayout(windows: [window(1, x: 1250), window(2, x: 1200, y: 400)], screens: [builtIn])
        XCTAssertTrue(layout.copies(of: CGRect(x: 1200, y: 4.5, width: 24, height: 24)).isEmpty)
    }

    func testCopiesMatchByPositionFromTheRightOnEveryScreen() {
        // The built-in row overflows: its leftmost item is ordered out.
        let windows = [
            window(1, x: 1440), window(2, x: 1400, width: 30), window(3, x: 1360, onscreen: false),
            window(11, x: 1674, y: -1080), window(12, x: 1634, width: 30, y: -1080), window(13, x: 1594, y: -1080),
        ]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        let fromExternal = layout.copies(of: CGRect(x: 1594, y: -1076, width: 24, height: 24))
        XCTAssertEqual(fromExternal.mapValues(\.id), [0: 3, 1: 13])
        let fromBuiltIn = layout.copies(of: CGRect(x: 1400, y: 4, width: 30, height: 24))
        XCTAssertEqual(fromBuiltIn.mapValues(\.id), [0: 2, 1: 12])
    }

    func testCopiesIncludeARowParkedAboveItsScreen() {
        // A hidden (auto-hiding or full screen) menu bar parks its row above the screen.
        let windows = [window(1, x: 1440), window(11, x: 1674, y: -1142, onscreen: false)]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        XCTAssertEqual(layout.copies(of: CGRect(x: 1674, y: -1139, width: 24, height: 24)).mapValues(\.id),
                       [0: 1, 1: 11])
    }

    func testCopiesTolerateAButtonReportedAFewPointsOff() {
        // Accessibility can lag a relayout by a few points; most of the button
        // still overlaps its window.
        let layout = MenuBarLayout(windows: [window(1, x: 830), window(2, x: 800)], screens: [builtIn])
        XCTAssertEqual(layout.copies(of: CGRect(x: 824, y: 4.5, width: 29, height: 24)).mapValues(\.id), [0: 1])
    }

    func testCopiesFollowAnItemThatOverflowReordered() {
        // The built-in row ran out of room for Telegram (30 wide) but still fit
        // T1 (27 wide) further right, so the two swap places across screens.
        let windows = [
            window(1, x: 1430, width: 34), window(2, x: 1400, width: 21), window(3, x: 1370, onscreen: false),
            window(11, x: 1664, width: 34, y: -1080), window(12, x: 1634, y: -1080), window(13, x: 1604, width: 21, y: -1080),
        ]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        XCTAssertEqual(layout.copies(of: CGRect(x: 1634, y: -1076, width: 24, height: 24)).mapValues(\.id),
                       [0: 3, 1: 12])
        XCTAssertEqual(layout.copies(of: CGRect(x: 1604, y: -1076, width: 21, height: 24)).mapValues(\.id),
                       [0: 2, 1: 13])
    }

    func testCopiesFallBackToTheSameScreensRowWhenItMoved() {
        // Accessibility still reports the shown row after the menu bar parked it.
        let windows = [window(1, x: 1440), window(11, x: 1674, y: -1142, onscreen: false)]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        XCTAssertEqual(layout.copies(of: CGRect(x: 1674, y: -1076, width: 24, height: 24)).mapValues(\.id),
                       [0: 1, 1: 11])
    }

    func testCopiesSkipARowWhoseItemHasAnotherWidth() {
        let windows = [window(1, x: 1440, width: 40), window(11, x: 1674, y: -1080)]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        XCTAssertEqual(layout.copies(of: CGRect(x: 1674, y: -1076, width: 24, height: 24)).mapValues(\.id), [1: 11])
    }

    func testRowsLeaveOutTallWindows() {
        let tall = StatusWindow(id: 9, frame: CGRect(x: 1300, y: 28, width: 353, height: 508), isOnscreen: false)
        let layout = MenuBarLayout(windows: [window(1, x: 1440), tall], screens: [builtIn])
        XCTAssertEqual(layout.rows[0]?.map(\.id), [1])
    }
}

final class StatusWindowTests: XCTestCase {
    func testOffscreenWindowOnTheMenuBarIsHidden() {
        // macOS 26 keeps an overflowed item's window in the row but orders it out,
        // even when it sits just right of the notch.
        let frame = CGRect(x: 870, y: 0, width: 24, height: 32)
        XCTAssertEqual(Geometry.visibility(of: frame, screens: [builtIn], window: window(1, x: 870, onscreen: false)),
                       .hiddenByNotch)
    }

    func testOnscreenWindowFallsBackToGeometry() {
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 1200, y: 0, width: 24, height: 32), screens: [builtIn],
                                           window: window(1, x: 1200)), .visible)
        XCTAssertEqual(Geometry.visibility(of: CGRect(x: 700, y: 0, width: 24, height: 32), screens: [builtIn],
                                           window: window(1, x: 700)), .hiddenByNotch)
    }

    func testOffscreenWindowOffEveryScreenIsOffscreen() {
        let frame = CGRect(x: 1200, y: -1142, width: 24, height: 32)
        XCTAssertEqual(Geometry.visibility(of: frame, screens: [builtIn],
                                           window: window(1, x: 1200, y: -1142, onscreen: false)), .offscreen)
    }

    func testItemsWithoutAWindowAreDropped() {
        let items = [item("shown", x: 1200), item("phantom", x: 800), item("noFrame", x: nil),
                     item("zero", x: 0, width: 0)]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn], windows: [window(7, x: 1200)])
        XCTAssertEqual(sorted.map(\.id), ["shown", "noFrame"])
        XCTAssertEqual(sorted.map(\.windowID), [7, nil])
    }

    func testWithoutWindowListEveryItemIsKept() {
        let items = [item("a", x: 1200), item("b", x: 800)]
        XCTAssertEqual(ExtraList.classifyAndSort(items, screens: [builtIn]).map(\.id), ["b", "a"])
    }

    func testHiddenOverflowListsLeftToRight() {
        let items = [item("visible", x: 1200), item("right", x: 870), item("left", x: 700)]
        let windows = [window(1, x: 1200), window(2, x: 870, onscreen: false), window(3, x: 700, onscreen: false)]
        let hidden = ExtraList.classifyAndSort(items, screens: [builtIn], windows: windows).filter(\.visibility.isHidden)
        XCTAssertEqual(hidden.map(\.id), ["left", "right"])
    }

    func testItemReportedOnAnotherScreenIsJudgedOnTheNotchedOne() {
        // Accessibility may report an item's copy on another screen. It's judged
        // by its copy on the notched screen, and captured from a drawn copy.
        let windows = [window(1, x: 1440), window(3, x: 1410, onscreen: false),
                       window(11, x: 1674, y: -1080), window(13, x: 1644, y: -1080)]
        let items = [
            ExtraItem(id: "shown", pid: 1, appName: "A", frame: CGRect(x: 1674, y: -1076, width: 24, height: 24)),
            ExtraItem(id: "overflowed", pid: 1, appName: "B", frame: CGRect(x: 1644, y: -1076, width: 24, height: 24)),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn, external], windows: windows)
        XCTAssertEqual(sorted.map(\.id), ["overflowed", "shown"])
        XCTAssertEqual(sorted.map(\.visibility), [.hiddenByNotch, .visible])
        XCTAssertEqual(sorted.map(\.windowID), [13, 1])
    }

    func testOverflowWithoutANotchIsHiddenToo() {
        let plain = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        let items = [item("a", x: 700)]
        let sorted = ExtraList.classifyAndSort(items, screens: [plain], windows: [window(1, x: 700, onscreen: false)])
        XCTAssertEqual(sorted.map(\.visibility), [.hiddenByNotch])
    }
}

final class WindowNameTests: XCTestCase {
    private func named(_ id: UInt32, x: CGFloat, width: CGFloat, name: String?, onscreen: Bool = true) -> StatusWindow {
        StatusWindow(id: id, frame: CGRect(x: x, y: 0, width: width, height: 33), isOnscreen: onscreen, name: name)
    }

    func testNamesOverrideStalePositions() {
        // Accessibility still has Telegram where T1 now is, and T1 where
        // Telegram went; the window names tell them apart.
        let windows = [named(1, x: 857, width: 27, name: "75613"),
                       named(2, x: 827, width: 30, name: "com.tdesktop.Telegram", onscreen: false)]
        var telegram = ExtraItem(id: "telegram", pid: 600, appName: "Telegram", bundleID: "com.tdesktop.Telegram",
                                 frame: CGRect(x: 855, y: 4.5, width: 24, height: 24))
        telegram.role = ExtraList.menuBarItemRole
        let test = ExtraItem(id: "t1", pid: 75613, appName: "fill", frame: CGRect(x: 824, y: 4.5, width: 29, height: 24))
        let sorted = ExtraList.classifyAndSort([telegram, test], screens: [builtIn], windows: windows)
        XCTAssertEqual(sorted.map(\.id), ["telegram", "t1"])
        XCTAssertEqual(sorted.map(\.visibility), [.hiddenByNotch, .visible])
    }

    func testSeveralItemsOfOneAppPairInOrderFromTheRight() {
        let windows = [named(1, x: 1000, width: 30, name: "42"), named(2, x: 900, width: 30, name: "42", onscreen: false)]
        let items = [
            ExtraItem(id: "left", pid: 42, appName: "A", frame: CGRect(x: 880, y: 4, width: 30, height: 24)),
            ExtraItem(id: "right", pid: 42, appName: "A", frame: CGRect(x: 960, y: 4, width: 30, height: 24)),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn], windows: windows)
        XCTAssertEqual(sorted.map(\.id), ["left", "right"])
        XCTAssertEqual(sorted.map(\.windowID), [2, 1])
        XCTAssertEqual(sorted.map(\.visibility), [.hiddenByNotch, .visible])
    }

    func testAWindowClaimedByNameIsntMatchedAgainByPosition() {
        // A Control Center element with a stale frame lands on flomo's window.
        let windows = [named(1, x: 820, width: 30, name: "com.flomoapp.m", onscreen: false)]
        let flomo = ExtraItem(id: "flomo", pid: 5, appName: "flomo", bundleID: "com.flomoapp.m",
                              frame: CGRect(x: 868, y: 4, width: 26, height: 24))
        let stale = ExtraItem(id: "cc", pid: 9, appName: "Control Center", bundleID: "com.apple.controlcenter",
                              frame: CGRect(x: 822, y: 4, width: 26, height: 24))
        let sorted = ExtraList.classifyAndSort([flomo, stale], screens: [builtIn], windows: windows)
        XCTAssertEqual(sorted.map(\.id), ["flomo"])
    }

    func testMismatchedCountsFallBackToPositions() {
        let windows = [named(1, x: 1000, width: 30, name: "42")]
        let items = [
            ExtraItem(id: "a", pid: 42, appName: "A", frame: CGRect(x: 1000, y: 4, width: 30, height: 24)),
            ExtraItem(id: "b", pid: 42, appName: "A", frame: CGRect(x: 700, y: 4, width: 30, height: 24)),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn], windows: windows)
        XCTAssertEqual(sorted.map(\.id), ["a"])
        XCTAssertEqual(sorted.map(\.windowID), [1])
    }
}

final class ActiveRowNameTests: XCTestCase {
    func testNamesFromTheActiveMenuBarCarryToTheNotchedOne() {
        // Only the active menu bar (here the external one) names its windows
        // after apps; the built-in row has autosave names. flomo's stale frame
        // sits on WeChat's built-in window, but its name on the external row
        // finds its own.
        let windows = [
            StatusWindow(id: 1, frame: CGRect(x: 1400, y: 0, width: 38, height: 33), isOnscreen: true, name: "Item-0"),
            StatusWindow(id: 2, frame: CGRect(x: 1376, y: 0, width: 24, height: 33), isOnscreen: false, name: "Item-0"),
            StatusWindow(id: 11, frame: CGRect(x: 1634, y: -1080, width: 38, height: 33), isOnscreen: true,
                         name: "com.tencent.xinWeChat"),
            StatusWindow(id: 12, frame: CGRect(x: 1610, y: -1080, width: 24, height: 33), isOnscreen: true,
                         name: "com.flomoapp.m"),
        ]
        let items = [
            ExtraItem(id: "wechat", pid: 1, appName: "WeChat", bundleID: "com.tencent.xinWeChat",
                      frame: CGRect(x: 1634, y: -1076, width: 38, height: 24)),
            ExtraItem(id: "flomo", pid: 2, appName: "flomo", bundleID: "com.flomoapp.m",
                      frame: CGRect(x: 1405, y: 4, width: 24, height: 24)),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn, external], windows: windows)
        XCTAssertEqual(sorted.map(\.id), ["flomo", "wechat"])
        XCTAssertEqual(sorted.map(\.visibility), [.hiddenByNotch, .visible])
        XCTAssertEqual(sorted.map(\.windowID), [12, 1])
    }
}

final class LaunchOrderTests: XCTestCase {
    private func entry(_ id: String, pid: Int32, bundleID: String?, x: CGFloat) -> ClassifiedItem {
        ClassifiedItem(item: ExtraItem(id: id, pid: pid, appName: id, bundleID: bundleID,
                                       frame: CGRect(x: x, y: 0, width: 24, height: 24)),
                       visibility: .hiddenByNotch)
    }

    func testSystemItemsGoRightAndAppsLeftInLaunchOrder() {
        let start = Date(timeIntervalSince1970: 1000)
        let items = [
            entry("cc", pid: 1, bundleID: "com.apple.controlcenter", x: 100),
            entry("old", pid: 2, bundleID: "a.old", x: 300),
            entry("new", pid: 3, bundleID: "a.new", x: 200),
            entry("mid", pid: 4, bundleID: "a.mid", x: 400),
        ]
        let launched: [Int32: Date] = [2: start, 3: start + 20, 4: start + 10]
        XCTAssertEqual(ExtraList.inMenuBarOrder(items, launchDates: launched).map(\.id), ["new", "mid", "old", "cc"])
    }

    func testAnAppsItemsKeepTheirPlaceAndUnknownLaunchesGoLeft() {
        let start = Date(timeIntervalSince1970: 1000)
        let items = [
            entry("a-right", pid: 2, bundleID: "a", x: 500),
            entry("a-left", pid: 2, bundleID: "a", x: 400),
            entry("unknown", pid: 9, bundleID: nil, x: 900),
        ]
        XCTAssertEqual(ExtraList.inMenuBarOrder(items, launchDates: [2: start]).map(\.id),
                       ["unknown", "a-left", "a-right"])
    }
}

final class StackSlotTests: XCTestCase {
    // builtIn: 1512 wide, notch 654…858.
    private let leftmost = CGRect(x: 944, y: 0, width: 38, height: 33)

    func testRightOfTheNotchWhenMenusAreShort() {
        XCTAssertEqual(Geometry.stackSlot(width: 26, screens: [builtIn], screen: 0,
                                          appMenus: CGRect(x: 0, y: 0, width: 400, height: 24),
                                          leftmostShown: leftmost), 942)
    }

    func testAfterMenusThatRunPastTheNotch() {
        XCTAssertEqual(Geometry.stackSlot(width: 26, screens: [builtIn], screen: 0,
                                          appMenus: CGRect(x: 0, y: 0, width: 905, height: 24),
                                          leftmostShown: leftmost), 942)
    }

    func testLeftOfTheNotchWhenTheRightGapIsTooNarrow() {
        let close = CGRect(x: 870, y: 0, width: 38, height: 33)
        XCTAssertEqual(Geometry.stackSlot(width: 26, screens: [builtIn], screen: 0,
                                          appMenus: CGRect(x: 0, y: 0, width: 400, height: 24),
                                          leftmostShown: close), 650)
    }

    func testNoSlotWhenMenusFillUpToTheItems() {
        XCTAssertNil(Geometry.stackSlot(width: 26, screens: [builtIn], screen: 0,
                                        appMenus: CGRect(x: 0, y: 0, width: 930, height: 24),
                                        leftmostShown: leftmost))
    }

    func testMenusReadOnAnotherScreenKeepTheirWidth() {
        let external = ScreenInfo(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        XCTAssertNil(Geometry.stackSlot(width: 26, screens: [external, builtIn], screen: 1,
                                        appMenus: CGRect(x: -1920, y: 0, width: 930, height: 24),
                                        leftmostShown: leftmost))
    }

    func testWithoutANotchOnlyAfterTheMenus() {
        let plain = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        XCTAssertEqual(Geometry.stackSlot(width: 26, screens: [plain], screen: 0,
                                          appMenus: CGRect(x: 0, y: 0, width: 400, height: 24),
                                          leftmostShown: leftmost), 942)
        XCTAssertNil(Geometry.stackSlot(width: 26, screens: [plain], screen: 0,
                                        appMenus: CGRect(x: 0, y: 0, width: 930, height: 24),
                                        leftmostShown: leftmost))
    }
}

final class StackPlacementTests: XCTestCase {
    // builtIn: notch 654…858; status windows 33 high at the top.
    private func shown(_ id: UInt32, x: CGFloat, width: CGFloat = 30, onscreen: Bool = true) -> StatusWindow {
        StatusWindow(id: id, frame: CGRect(x: x, y: 0, width: width, height: 33), isOnscreen: onscreen)
    }
    private let shortMenus = CGRect(x: 0, y: 0, width: 400, height: 24)

    func testOwnIconAtTheLeftEndHoldsTheItems() {
        let layout = MenuBarLayout(windows: [shown(1, x: 1200), shown(2, x: 1000)], screens: [builtIn])
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: shortMenus,
                                        own: CGRect(x: 1000, y: 0, width: 30, height: 33), coverable: []),
                       .ownIcon(shown(2, x: 1000)))
    }

    func testOwnIconReportedOnAnotherScreenStillHoldsTheItems() {
        // With an external display, Hairpin's icon can report its copy in the
        // other menu bar (here parked above its screen); its copy in the
        // notched one is the leftmost shown item there.
        let windows = [shown(1, x: 1200), shown(2, x: 1000), shown(3, x: 970, onscreen: false),
                       StatusWindow(id: 11, frame: CGRect(x: 1674, y: -1142, width: 30, height: 30), isOnscreen: false),
                       StatusWindow(id: 12, frame: CGRect(x: 1644, y: -1142, width: 30, height: 30), isOnscreen: false),
                       StatusWindow(id: 13, frame: CGRect(x: 1614, y: -1142, width: 30, height: 30), isOnscreen: false)]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: shortMenus,
                                        own: CGRect(x: 1647, y: -1139, width: 24, height: 24), coverable: [1]),
                       .ownIcon(shown(2, x: 1000)))
    }

    func testOwnIconHiddenInTheNotchedMenuBarDoesntHoldTheItems() {
        // Shown in the other menu bar, but overflowed in the notched one.
        let windows = [shown(1, x: 1200), shown(2, x: 970, onscreen: false),
                       StatusWindow(id: 11, frame: CGRect(x: 1674, y: -1080, width: 30, height: 33), isOnscreen: true),
                       StatusWindow(id: 12, frame: CGRect(x: 1644, y: -1080, width: 30, height: 33), isOnscreen: true)]
        let layout = MenuBarLayout(windows: windows, screens: [builtIn, external])
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: shortMenus,
                                        own: CGRect(x: 1647, y: -1076, width: 24, height: 24), coverable: [1]),
                       .slot(rightEdge: 1198))
    }

    func testANarrowGapRightOfTheNotchFitsThePin() {
        // 26 points from the notch to the leftmost item, as beside Codex's pill.
        let layout = MenuBarLayout(windows: [shown(1, x: 884, width: 48)], screens: [builtIn])
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: shortMenus, own: nil, coverable: [1]),
                       .slot(rightEdge: 882))
    }

    func testWithNoRoomThePinCoversTheLeftmostKnownItem() {
        let unknown = shown(1, x: 935, width: 24), known = shown(2, x: 960)
        let layout = MenuBarLayout(windows: [shown(3, x: 1200), known, unknown], screens: [builtIn])
        let longMenus = CGRect(x: 0, y: 0, width: 930, height: 24)
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: longMenus, own: nil, coverable: [2, 3]),
                       .covering(known))
    }

    func testWithNoRoomOurShownIconHoldsTheItemsRatherThanCoverOne() {
        // Howler, relaunched, went left of Hairpin's icon, leaving too little
        // room beside the notch: covering Howler would show a pin beside ours.
        let howler = shown(1, x: 860), own = shown(2, x: 890)
        let layout = MenuBarLayout(windows: [shown(3, x: 1200), own, howler], screens: [builtIn])
        let menusToTheNotch = CGRect(x: 0, y: 0, width: 650, height: 24)
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: menusToTheNotch, own: nil, ownWindows: [2],
                                        coverable: [1, 3]),
                       .ownIcon(own))
    }

    func testOurShownIconHoldsTheItemsEvenWithRoomForAPin() {
        // Short menus leave room left of the notch, but a pin there would
        // be a second one beside Hairpin's icon.
        let howler = shown(1, x: 860), own = shown(2, x: 890)
        let layout = MenuBarLayout(windows: [shown(3, x: 1200), own, howler], screens: [builtIn])
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: shortMenus, own: nil, ownWindows: [2],
                                        coverable: [1, 3]),
                       .ownIcon(own))
    }

    func testNoPinWithNothingToCover() {
        let layout = MenuBarLayout(windows: [shown(1, x: 935, width: 24)], screens: [builtIn])
        let longMenus = CGRect(x: 0, y: 0, width: 930, height: 24)
        XCTAssertNil(layout.placement(width: 20, screen: 0, appMenus: longMenus, own: nil, coverable: []))
    }

    func testNoPinWhileTheMenuBarIsParked() {
        // Auto-hide and full screen park the row above the screen.
        let parked = StatusWindow(id: 1, frame: CGRect(x: 1200, y: -62, width: 30, height: 30), isOnscreen: false)
        let layout = MenuBarLayout(windows: [parked], screens: [builtIn])
        XCTAssertFalse(layout.isShowing(0))
        XCTAssertNil(layout.placement(width: 20, screen: 0, appMenus: nil, own: nil, coverable: [1]))
    }

    func testItemsUnderTheNotchDontCountAsShown() {
        // Before macOS 26 an overflowed window stays onscreen under the notch.
        let layout = MenuBarLayout(windows: [shown(1, x: 1000), shown(2, x: 800)], screens: [builtIn])
        XCTAssertTrue(layout.isShowing(0))
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: nil, own: nil, coverable: []),
                       .slot(rightEdge: 998))
    }

    func testTargetIsTheNotchedScreen() {
        let plain = ScreenInfo(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(MenuBarLayout.targetScreen(in: [plain, builtIn]), 1)
        XCTAssertEqual(MenuBarLayout.targetScreen(in: [plain]), 0)
    }

    func testClassifiedItemsCarryTheirJudgedWindow() {
        let windows = [window(1, x: 1440), window(3, x: 1410, onscreen: false),
                       window(11, x: 1674, y: -1080), window(13, x: 1644, y: -1080)]
        let items = [
            ExtraItem(id: "shown", pid: 1, appName: "A", frame: CGRect(x: 1674, y: -1076, width: 24, height: 24)),
            ExtraItem(id: "overflowed", pid: 1, appName: "B", frame: CGRect(x: 1644, y: -1076, width: 24, height: 24)),
        ]
        let sorted = ExtraList.classifyAndSort(items, screens: [builtIn, external], windows: windows)
        XCTAssertEqual(sorted.map(\.judgedWindowID), [3, 1])
    }
}

/// Recorded on macOS 26 with an external display: the built-in row keeps its
/// overflowed item (Howler) at its left end, while the external row has it
/// second from the left, so the two rows don't line up by position.
final class WindowOwnerTests: XCTestCase {
    private func bar(_ id: UInt32, x: CGFloat, width: CGFloat = 30, onscreen: Bool = true) -> StatusWindow {
        StatusWindow(id: id, frame: CGRect(x: x, y: 0, width: width, height: 33), isOnscreen: onscreen)
    }
    private func outer(_ id: UInt32, x: CGFloat, width: CGFloat = 30, parked: Bool = true) -> StatusWindow {
        StatusWindow(id: id, frame: CGRect(x: x, y: parked ? -1142 : -1080, width: width, height: parked ? 30 : 33),
                     isOnscreen: !parked)
    }
    /// Howler 51/49, Hairpin 57/56, ChatGPT 44/80, the clock 99/98.
    private func windows(externalParked parked: Bool = true) -> [StatusWindow] {
        [bar(51, x: 870, onscreen: false), bar(57, x: 900), bar(44, x: 930), bar(99, x: 960, width: 159),
         outer(56, x: 1300, parked: parked), outer(49, x: 1330, parked: parked),
         outer(80, x: 1360, parked: parked), outer(98, x: 1390, width: 159, parked: parked)]
    }
    private let screens = [builtIn, external]
    private let howlerOnExternal = ExtraItem(id: "howler", pid: 1, appName: "Howler",
                                             frame: CGRect(x: 1333, y: -1139, width: 24, height: 24))
    private let howlerOnBuiltIn = ExtraItem(id: "howler", pid: 1, appName: "Howler",
                                            frame: CGRect(x: 873, y: 4.5, width: 24, height: 24))
    private let chatGPTOnExternal = ExtraItem(id: "chatgpt", pid: 2, appName: "ChatGPT",
                                              frame: CGRect(x: 1363, y: -1139, width: 24, height: 24))

    func testEachItemOwnsTheWindowsItsReportedOn() {
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        let owners = layout.windowOwners(for: [howlerOnBuiltIn, chatGPTOnExternal],
                                         keeping: [49: "howler", 80: "chatgpt", 44: "chatgpt", 12: "gone"])
        // Claims in rows where an item isn't reported now stand; the window
        // that's gone is dropped.
        XCTAssertEqual(owners, [49: "howler", 51: "howler", 80: "chatgpt", 44: "chatgpt"])
    }

    func testAnOwnedWindowJudgesAnItemReportedInAnotherRow() {
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        let sorted = ExtraList.classifyAndSort([howlerOnExternal, chatGPTOnExternal], screens: screens,
                                               appMenus: nil, layout: layout, owners: [51: "howler", 49: "howler"])
        XCTAssertEqual(sorted.map(\.id), ["howler", "chatgpt"])
        XCTAssertEqual(sorted.map(\.judgedWindowID), [51, 44])
        XCTAssertEqual(sorted.map(\.visibility), [.hiddenByNotch, .visible])
    }

    func testCopiesThatSwappedRowsAreStillFound() {
        // macOS can hand an item's copies to the other menu bar: what was
        // Howler's external window is now its built-in one.
        var swapped = windows()
        swapped[0].id = 49
        swapped[5].id = 51
        let layout = MenuBarLayout(windows: swapped, screens: screens)
        let sorted = ExtraList.classifyAndSort([howlerOnExternal], screens: screens, appMenus: nil, layout: layout,
                                               owners: [51: "howler", 49: "howler"])
        XCTAssertEqual(sorted.first?.judgedWindowID, 49)
    }

    func testAHiddenItemIsDrawnByItsOwnCopyInTheOtherRow() {
        let layout = MenuBarLayout(windows: windows(externalParked: false), screens: screens)
        var howler = howlerOnExternal
        howler.frame = CGRect(x: 1333, y: -1076, width: 24, height: 24)
        let sorted = ExtraList.classifyAndSort([howler], screens: screens, appMenus: nil, layout: layout,
                                               owners: [51: "howler"])
        XCTAssertEqual(sorted.first?.windowID, 49)
    }

    func testWithoutOwnersItemsFallBackToTheirPlace() {
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        let sorted = ExtraList.classifyAndSort([chatGPTOnExternal], screens: screens, appMenus: nil, layout: layout)
        XCTAssertEqual(sorted.first?.judgedWindowID, 44)
    }

    func testWithoutOurWindowsTheRowsLineUpAgain() {
        // Our icon sits right of the hidden items in the notched row but
        // left of them elsewhere; left out, the rest line up by place.
        let layout = MenuBarLayout(windows: windows().filter { ![56, 57].contains($0.id) }, screens: screens)
        let sorted = ExtraList.classifyAndSort([howlerOnExternal, chatGPTOnExternal], screens: screens,
                                               appMenus: nil, layout: layout)
        XCTAssertEqual(sorted.map(\.judgedWindowID), [51, 44])
    }

    func testOwnIconFoundByItsWindows() {
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        let own = CGRect(x: 1300, y: -1142, width: 30, height: 30)
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: nil, own: own, ownWindows: [56, 57],
                                        coverable: [44]),
                       .ownIcon(bar(57, x: 900)))
    }

    func testOwnIconHiddenByItsWindowsGetsAPin() {
        // Hairpin's icon overflowed, though its frame lands on the shown item.
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: nil, own: CGRect(x: 903, y: 4, width: 24, height: 24),
                                        ownWindows: [51], coverable: [44]),
                       .slot(rightEdge: 898))
    }

    func testOwnIconWithoutKnownWindowsFallsBackToItsPlace() {
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        let own = CGRect(x: 1300, y: -1142, width: 30, height: 30)
        XCTAssertEqual(layout.placement(width: 20, screen: 0, appMenus: nil, own: own, ownWindows: [12],
                                        coverable: [44]),
                       .slot(rightEdge: 898))
    }

    func testWindowsThatGrewAreOurs() {
        let before = windows()
        var after = before
        after[1].frame.size.width += 2   // 57, built-in
        after[1].frame.origin.x -= 2
        after[0].frame.origin.x -= 2     // pushed left, same width
        after[4].frame.size.width += 2   // 56, external
        XCTAssertEqual(MenuBarLayout.grownWindows(from: before, to: after, by: 2, screens: screens), [56, 57])
    }

    func testAnotherItemGrowingSpoilsTheProbe() {
        // A network meter widening at the same moment leaves two candidates
        // in a row; nothing is taken for ours.
        let before = windows()
        var after = before
        after[1].frame.size.width += 2
        after[4].frame.size.width += 2
        after[2].frame.size.width += 2
        XCTAssertEqual(MenuBarLayout.grownWindows(from: before, to: after, by: 2, screens: screens), [])
    }

    func testAProbeMissingARowFindsNothing() {
        // Only one copy grew (its other menu bar didn't relayout yet): a
        // partial answer would misalign the rows, so there's none.
        let before = windows()
        var after = before
        after[4].frame.size.width += 2
        XCTAssertEqual(MenuBarLayout.grownWindows(from: before, to: after, by: 2, screens: screens), [])
    }

    func testWindowsGrowingByOtherAmountsArentOurs() {
        let before = windows()
        var after = before
        after[1].frame.size.width += 2
        after[4].frame.size.width += 9
        XCTAssertEqual(MenuBarLayout.grownWindows(from: before, to: after, by: 2, screens: screens), [])
    }

    func testAnItemSeenOnANewWindowDropsItsOldClaims() {
        // An app dropped its first item, so its item ids shifted: "p-0" is now
        // reported on what was "p-1"'s window. Neither id's old claims hold.
        let layout = MenuBarLayout(windows: windows(), screens: screens)
        let shifted = ExtraItem(id: "p-0", pid: 3, appName: "P", frame: CGRect(x: 1333, y: -1139, width: 24, height: 24))
        let owners = layout.windowOwners(for: [shifted], keeping: [56: "p-0", 57: "p-0", 49: "p-1", 51: "p-1"])
        XCTAssertEqual(owners, [49: "p-0"])
    }
}
