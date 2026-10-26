import Foundation
import CoreGraphics

/// A display, described in global Quartz coordinates (origin at the top-left
/// of the primary display, y grows downward) — the same space Accessibility
/// reports `AXPosition` in.
public struct ScreenInfo: Equatable, Sendable {
    public var frame: CGRect
    /// The area covered by the camera housing, if the display has one.
    public var notch: CGRect?

    public init(frame: CGRect, notch: CGRect? = nil) {
        self.frame = frame
        self.notch = notch
    }
}

public enum ItemVisibility: Int, Comparable, Sendable {
    /// Behind the notch, or left of it where the frontmost app's menus cover it.
    case hiddenByNotch
    /// Not (mostly) on any screen.
    case offscreen
    case visible
    /// The item did not report a frame.
    case unknown

    public var isHidden: Bool { section == .hidden }

    public var section: ItemSection {
        switch self {
        case .hiddenByNotch, .offscreen: return .hidden
        case .visible: return .visible
        case .unknown: return .unknown
        }
    }

    public static func < (lhs: ItemVisibility, rhs: ItemVisibility) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The menu section an item is listed under, in menu order.
public enum ItemSection: Int, Comparable, Sendable {
    case hidden
    case visible
    case unknown

    public static func < (lhs: ItemSection, rhs: ItemSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum Geometry {
    /// Converts a Cocoa rect (origin bottom-left of the primary display, y up)
    /// into Quartz coordinates (origin top-left of the primary display, y down).
    public static func quartzRect(fromCocoa rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    /// Derives the notch rect (Cocoa coordinates) from the screen frame and the
    /// two unobscured top areas reported by `NSScreen.auxiliaryTopLeftArea` /
    /// `auxiliaryTopRightArea`. Returns nil when the display has no notch.
    ///
    /// The areas are accepted either in global coordinates or relative to the
    /// screen's origin; both are normalized to global coordinates.
    public static func notchRect(screenFrame: CGRect, topLeftArea: CGRect?, topRightArea: CGRect?) -> CGRect? {
        guard let left = topLeftArea, let right = topRightArea,
              !left.isEmpty, !right.isEmpty else { return nil }
        // Global areas hug the screen's top edge; local ones hug `height`.
        let isGlobal = abs(left.maxY - screenFrame.maxY) <= 1
            && left.minX >= screenFrame.minX - 1
            && right.maxX <= screenFrame.maxX + 1
        let dx = isGlobal ? 0 : screenFrame.minX
        let dy = isGlobal ? 0 : screenFrame.minY
        let l = left.offsetBy(dx: dx, dy: dy)
        let r = right.offsetBy(dx: dx, dy: dy)
        guard r.minX - l.maxX > 0 else { return nil }
        let height = max(l.height, r.height)
        return CGRect(x: l.maxX, y: screenFrame.maxY - height, width: r.minX - l.maxX, height: height)
    }

    /// Classifies a menu bar item frame (Quartz coordinates).
    ///
    /// `appMenus` is the extent of the frontmost app's menus (Apple menu
    /// through its last menu), if it could be read.
    public static func visibility(of frame: CGRect?, screens: [ScreenInfo], appMenus: CGRect? = nil,
                                  minimumVisibleFraction: CGFloat = 0.5) -> ItemVisibility {
        guard let frame else { return .unknown }
        guard frame.width > 0, frame.height > 0 else { return .offscreen }

        // App menus start at the left edge of the screen they're on, and every
        // menu bar shows the same menus, so their width carries across screens.
        let menuWidth = appMenus.flatMap { menus in
            screens.first { $0.frame.contains(CGPoint(x: menus.minX, y: menus.midY)) }
                .map { menus.maxX - $0.frame.minX }
        }

        // On a notched display, status items are laid out right-to-left. Once
        // they run out of room they continue under the notch, and then to its
        // left, where the frontmost app's menus are drawn over them.
        for screen in screens {
            guard let notch = screen.notch, frame.intersects(screen.frame),
                  frame.minY < notch.maxY else { continue }
            if frame.minX < notch.maxX - 1 && frame.maxX > notch.minX + 1 {
                return .hiddenByNotch
            }
            if frame.maxX <= notch.minX + 1 {
                // Without the menus' extent, assume they cover it.
                guard let menuWidth else { return .hiddenByNotch }
                if frame.minX < screen.frame.minX + menuWidth - 1 { return .hiddenByNotch }
            }
        }

        let area = frame.width * frame.height
        let visibleArea = screens.reduce(CGFloat(0)) { sum, screen in
            let overlap = frame.intersection(screen.frame)
            return overlap.isNull ? sum : sum + overlap.width * overlap.height
        }
        return visibleArea / area < minimumVisibleFraction ? .offscreen : .visible
    }
}
