import AppKit

/// One hidden menu bar item, ready to draw.
struct StackEntry: Equatable {
    let id: String
    let image: NSImage
    let toolTip: String
}

/// Where the hidden items are kept: at the left end of the shown items in a
/// screen's menu bar strip (Cocoa coordinates).
struct StackAnchor: Equatable {
    enum Place: Equatable {
        /// Hairpin's own icon is the leftmost shown item and holds them; its
        /// copy in this menu bar is at `frame`.
        case button(frame: NSRect)
        /// The pin spanning this part of the menu bar.
        case slot(minX: CGFloat, width: CGFloat)
    }

    var place: Place
    var row: NSRect
    /// The window of a shown item the pin sits on for lack of room; the pin
    /// then hides it, and it's kept with the hidden ones.
    var covered: UInt32?
}

/// Hairpin's pin at the left end of the shown menu bar items, where the
/// hidden ones overflowed. Resting the pointer on it drops the items down in
/// a row below it; clicking one opens it. With nothing hidden, the pin isn't
/// there. While Hairpin's own icon is the leftmost item, it holds them itself.
///
/// It opens on a click, and on hover unless `opensOnHover` is off. Opened by
/// hovering, the row closes when the pointer leaves; opened by a click, or
/// once an item in it is clicked (so the item's menu shows beside it), it
/// stays until a click lands anywhere else, the pin is clicked again, or
/// Escape is pressed.
@MainActor
final class NotchStack: NSObject {
    static let hoverDelay: TimeInterval = 0.5
    private static let collapseDelay: TimeInterval = 0.3
    /// The pin's own width: its 18-point mark and a point either side.
    static let pinWidth: CGFloat = 20
    private static let pinSide: CGFloat = 18
    /// The capsule the pin wears to hide an item it sits on.
    private static let chipHeight: CGFloat = 22
    /// Icons keep their menu bar size, in round cells that light up under
    /// the pointer.
    private static let iconSide: CGFloat = 22
    private static let cellSide: CGFloat = 34
    private static let cellSpacing: CGFloat = 2
    private static let listInset: CGFloat = 5
    private static let listGap: CGFloat = 6
    private static let screenMargin: CGFloat = 6

    /// The items are about to drop down: time to rescan and recapture.
    var onExpand: (() -> Void)?
    /// An item was clicked; the row stays open.
    var onSelect: ((String) -> Void)?
    /// The menu bar's light or dark look, which the pin is drawn for.
    var appearance: NSAppearance? {
        didSet {
            guard appearance?.name != oldValue?.name, let pile else { return }
            pile.appearance = appearance
            label(pile)
        }
    }
    /// Whether resting the pointer on the pin opens the row; a click always does.
    var opensOnHover = true

    private weak var button: NSStatusBarButton?
    private var entries: [StackEntry] = []
    private var anchor: StackAnchor?
    private var pile: NSPanel?
    private var list: NSPanel?
    private(set) var isExpanded = false
    private var expandTimer: Timer?
    private var collapseTimer: Timer?
    /// Set once an item is clicked: the row then waits for a click elsewhere.
    private var isPinned = false
    private var eventMonitors: [Any] = []
    /// Where a row opened without a pin hangs from.
    private var pointerOrigin: NSPoint?

    /// True while Hairpin's icon holds the items.
    var usesButton: Bool { !entries.isEmpty && buttonFrame != nil }

    /// Where Hairpin's icon holding the items is, in the menu bar the pin
    /// belongs to. Its button's own window can be its copy in another one.
    private var buttonFrame: NSRect? {
        guard case let .button(frame)? = anchor?.place else { return nil }
        return frame
    }

    /// Hairpin's own icon, which opens the items while it's the leftmost one.
    func attach(to button: NSStatusBarButton) {
        self.button = button
        button.addTrackingArea(NSTrackingArea(rect: .zero,
                                              options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                              owner: self, userInfo: nil))
    }

    func update(_ entries: [StackEntry], anchor: StackAnchor?) {
        guard entries != self.entries || anchor != self.anchor else { return }
        self.entries = entries
        self.anchor = anchor
        guard !entries.isEmpty else {
            hide()
            return
        }
        guard let anchor else {
            // No pin while the menu bar is hidden; a row opened at the
            // pointer stays.
            pile?.orderOut(nil)
            if pointerOrigin != nil {
                if isExpanded { showList(animated: false) }
            } else {
                hide()
            }
            return
        }
        switch anchor.place {
        case let .slot(minX, width):
            let pile = self.pile ?? makePanel()
            self.pile = pile
            pile.appearance = appearance
            pile.setFrame(NSRect(x: minX, y: anchor.row.minY, width: width, height: anchor.row.height), display: true)
            label(pile)
            pile.orderFrontRegardless()
        case .button:
            pile?.orderOut(nil)
        }
        if isExpanded { showList(animated: false) }
    }

    /// Opens the row; `pinned` keeps it open when the pointer leaves. False
    /// when there's nothing to open it from (no pin shown).
    @discardableResult
    func expand(pinned: Bool = false) -> Bool {
        expandTimer?.invalidate()
        expandTimer = nil
        if isExpanded {
            if pinned { pin() }
            return true
        }
        guard canOpen else { return false }
        onExpand?()
        // The rescan it starts can take the pin away (access revoked).
        guard canOpen else { return false }
        isExpanded = true
        isPinned = pinned
        showList(animated: true)
        watchClicks()
        return true
    }

    /// Opens the row to stay under the pointer, for when there's no pin to
    /// open it from (its menu bar hidden, or Hairpin's icon out of sight).
    @discardableResult
    func expandAtPointer() -> Bool {
        pointerOrigin = NSEvent.mouseLocation
        if expand(pinned: true) { return true }
        pointerOrigin = nil
        return false
    }

    private var canOpen: Bool {
        !entries.isEmpty && (pile?.isVisible == true || usesButton || pointerOrigin != nil)
    }

    /// A click on the pin: opens the row to stay, keeps a row that hovering
    /// opened, or closes a kept one.
    func toggle() {
        if isExpanded && isPinned { collapse() } else { expand(pinned: true) }
    }

    /// Keeps the open row open when the pointer leaves.
    private func pin() {
        isPinned = true
        collapseTimer?.invalidate()
        collapseTimer = nil
    }

    func collapse() {
        expandTimer?.invalidate()
        expandTimer = nil
        collapseTimer?.invalidate()
        collapseTimer = nil
        guard isExpanded else { return }
        isExpanded = false
        isPinned = false
        pointerOrigin = nil
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors = []
        guard let list else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            list.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                if !self.isExpanded { list.orderOut(nil) }
            }
        })
    }

    private func hide() {
        collapse()
        list?.orderOut(nil)
        pile?.orderOut(nil)
    }

    // MARK: - Hover

    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        collapseTimer?.invalidate()
        collapseTimer = nil
        // Entering the row only keeps it open; Hairpin's icon opens it only
        // while it holds the items itself.
        guard opensOnHover, isOpener(event.window), !isExpanded, expandTimer == nil else { return }
        expandTimer = Timer.scheduledTimer(withTimeInterval: Self.hoverDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.expand() }
        }
    }

    @objc(mouseExited:) func mouseExited(with event: NSEvent) {
        expandTimer?.invalidate()
        expandTimer = nil
        guard isExpanded, !isPinned else { return }
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: Self.collapseDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.collapse() }
        }
    }

    @objc private func pileClicked(_ sender: Any?) {
        toggle()
    }

    /// The pin, or Hairpin's icon while it holds the items.
    private func isOpener(_ window: NSWindow?) -> Bool {
        window != nil && (window === pile || (usesButton && window === button?.window))
    }

    private func select(_ id: String) {
        pin()
        onSelect?(id)
    }

    /// Closes the row on a click anywhere but in it or on the pin (which
    /// toggles it): in another app, an item's menu included, or in our other
    /// windows; and on Escape.
    private func watchClicks() {
        guard eventMonitors.isEmpty else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        let escape: UInt16 = 53
        let monitors: [Any?] = [
            NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
                MainActor.assumeIsolated { self?.collapse() }
            },
            NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self, event.window !== self.list, !self.isOpener(event.window) else { return }
                    self.collapse()
                }
                return event
            },
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                MainActor.assumeIsolated { if event.keyCode == escape { self?.collapse() } }
            },
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                MainActor.assumeIsolated { if event.keyCode == escape { self?.collapse() } }
                return event
            },
        ]
        eventMonitors = monitors.compactMap { $0 }
    }

    // MARK: - Drawing

    /// Draws the pin once, then tints it for the menu bar, puts it on a
    /// capsule that hides the item under it if it sits on one, and labels it
    /// with the count.
    private func label(_ pile: NSPanel) {
        guard let content = pile.contentView else { return }
        if content.subviews.isEmpty {
            let chip = NSView()
            chip.wantsLayer = true
            chip.layer?.cornerRadius = Self.chipHeight / 2
            chip.layer?.cornerCurve = .continuous
            chip.autoresizingMask = [.width, .minYMargin, .maxYMargin]
            content.addSubview(chip)
            let view = NSImageView(image: HairpinIcon.image(side: Self.pinSide))
            view.frame = content.bounds
            view.autoresizingMask = [.width, .height]
            view.imageAlignment = .alignCenter
            content.addSubview(view)
        }
        let chip = content.subviews[0], mark = content.subviews[1] as? NSImageView
        chip.isHidden = anchor?.covered == nil
        chip.frame = NSRect(x: 0, y: ((content.bounds.height - Self.chipHeight) / 2).rounded(),
                            width: content.bounds.width, height: Self.chipHeight)
        chip.layer?.backgroundColor = (isDark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.95, alpha: 1)).cgColor
        mark?.contentTintColor = foreground
        content.toolTip = entries.count == 1 ? "1 hidden icon" : "\(entries.count) hidden icons"
        content.setAccessibilityLabel(content.toolTip)
    }

    /// The hidden items in a row of glass under the pin, in menu bar order,
    /// icons as they look in the menu bar.
    private func showList(animated: Bool) {
        // Under the pin, Hairpin's icon or the pointer.
        let opener: NSRect, top: CGFloat
        if let origin = pointerOrigin {
            opener = NSRect(origin: origin, size: .zero)
            top = origin.y
        } else if let anchor, let frame = (usesButton ? buttonFrame : pile?.frame) {
            opener = frame
            top = anchor.row.minY
        } else {
            return
        }
        let list = self.list ?? makeList()
        self.list = list

        // As many cells per line as the screen holds; the rest wrap below.
        let center = NSPoint(x: opener.midX, y: opener.midY)
        guard let screen = (NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main)?.frame else { return }
        let room = screen.width - 2 * Self.screenMargin - 2 * Self.listInset + Self.cellSpacing
        let perLine = max(1, Int(room / (Self.cellSide + Self.cellSpacing)))
        let lines = stride(from: 0, to: entries.count, by: perLine).map { start -> NSView in
            let cells = entries[start..<min(start + perLine, entries.count)].map { entry in
                GlassItem(image: Self.fitted(entry.image, side: Self.iconSide), toolTip: entry.toolTip,
                          side: Self.cellSide) { [weak self] in self?.select(entry.id) }
            }
            let line = NSStackView(views: cells)
            line.spacing = Self.cellSpacing
            return line
        }
        let rows = NSStackView(views: lines)
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = Self.cellSpacing
        rows.edgeInsets = NSEdgeInsets(top: Self.listInset, left: Self.listInset,
                                       bottom: Self.listInset, right: Self.listInset)
        let size = rows.fittingSize
        rows.frame = NSRect(origin: .zero, size: size)
        // A capsule for one line, a rounded rect for more.
        let background = Self.glass(around: rows, cornerRadius: Self.cellSide / 2 + Self.listInset)
        background.frame = rows.frame
        background.addTrackingArea(NSTrackingArea(rect: .zero,
                                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                                  owner: self, userInfo: nil))
        list.contentView = background

        // Closing fades the row out; it comes back fully opaque, cutting short
        // a fade still running if it's reopened at once.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            list.animator().alphaValue = 1
        }
        let x = min(max(opener.midX - size.width / 2, screen.minX + Self.screenMargin),
                    screen.maxX - size.width - Self.screenMargin)
        let frame = NSRect(x: x, y: top - Self.listGap - size.height, width: size.width, height: size.height)
        guard animated else {
            list.setFrame(frame, display: true)
            list.orderFrontRegardless()
            return
        }
        // Slides down out of the menu bar. Only the position moves: fading
        // glass in makes it settle its tint visibly.
        list.setFrame(frame.offsetBy(dx: 0, dy: 10), display: true)
        list.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            list.animator().setFrame(frame, display: true)
        }
    }

    /// Liquid Glass on macOS 26, the popover's blur before it. The glass
    /// draws its own edge and shadow and keeps the icons on it legible.
    private static func glass(around content: NSView, cornerRadius: CGFloat) -> NSView {
        // NSGlassEffectView needs the macOS 26 SDK (Swift 6.2) to build.
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            return glass
        }
        #endif
        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.cornerCurve = .continuous
        blur.layer?.masksToBounds = true
        blur.addSubview(content)
        return blur
    }

    private var isDark: Bool {
        appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// The menu bar's icon color: white over a dark menu bar, black over a light one.
    private var foreground: NSColor { isDark ? .white : .black }

    private func makePanel() -> NSPanel {
        let panel = Self.panel()
        // Above the menu bar and status items, below menus.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        let content = NSView()
        content.addTrackingArea(NSTrackingArea(rect: .zero,
                                               options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                               owner: self, userInfo: nil))
        content.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(pileClicked(_:))))
        panel.contentView = content
        return panel
    }

    private func makeList() -> NSPanel {
        let panel = Self.panel()
        panel.level = .popUpMenu
        // The glass has its own shadow; the blur needs the window's.
        panel.hasShadow = true
        #if compiler(>=6.2)
        if #available(macOS 26, *) { panel.hasShadow = false }
        #endif
        return panel
    }

    private static func panel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Not on full-screen spaces, where the menu bar is hidden too.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return panel
    }

    /// Scales an icon down, never up, to fit a square.
    private static func fitted(_ image: NSImage, side: CGFloat) -> NSImage {
        let scale = min(side / max(image.size.width, 1), side / max(image.size.height, 1), 1)
        guard scale < 1 else { return image }
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        copy.isTemplate = image.isTemplate
        return copy
    }
}

/// One hidden item in the row: its icon in a round cell that lights up
/// under the pointer and runs `action` when clicked.
final class GlassItem: NSView {
    private let action: () -> Void
    private var isHovered = false { didSet { needsDisplay = true } }
    private var isPressed = false { didSet { needsDisplay = true } }

    init(image: NSImage, toolTip: String, side: CGFloat, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        wantsLayer = true
        let icon = NSImageView(image: image)
        icon.imageScaling = .scaleNone
        // Template icons take the label color the glass keeps legible.
        icon.contentTintColor = .labelColor
        icon.frame = bounds
        icon.autoresizingMask = [.width, .height]
        addSubview(icon)
        self.toolTip = toolTip
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(toolTip)
        widthAnchor.constraint(equalToConstant: side).isActive = true
        heightAnchor.constraint(equalToConstant: side).isActive = true
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var wantsUpdateLayer: Bool { true }

    /// The row's panel never becomes key; the first click is the one that counts.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateLayer() {
        let opacity: CGFloat = isPressed ? 0.22 : isHovered ? 0.12 : 0
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(opacity).cgColor
        layer?.cornerRadius = bounds.height / 2
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; isPressed = false }
    override func mouseDown(with event: NSEvent) { isPressed = true }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        if inside { action() }
    }

    override func accessibilityPerformPress() -> Bool {
        action()
        return true
    }
}
