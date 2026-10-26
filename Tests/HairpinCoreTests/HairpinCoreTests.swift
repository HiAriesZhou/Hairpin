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
