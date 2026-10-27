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
        /// Hairpin's own icon is the leftmost shown item and holds them.
        case button
        /// The pin spanning this part of the menu bar.
        case slot(minX: CGFloat, width: CGFloat)
    }

    var place: Place
    var row: NSRect
    /// A shown item the pin sits on for lack of room (Quartz); it's kept
    /// with the hidden ones.
    var covered: CGRect?
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
    static let pileWidth: CGFloat = 26
    private static let pinSide: CGFloat = 18
    /// Icons keep their menu bar size, in round cells that light up under
    /// the pointer.
    private static let iconSide: CGFloat = 22
    private static let cellSide: CGFloat = 34
    private static let cellSpacing: CGFloat = 2
    private static let listInset: CGFloat = 5
    private static let listGap: CGFloat = 6

    /// The items are about to drop down: time to rescan and recapture.
    var onExpand: (() -> Void)?
    /// An item was clicked; the row stays open.
    var onSelect: ((String) -> Void)?
    /// The menu bar's light or dark look, which captured icons are drawn for.
    var appearance: NSAppearance?
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

    /// True while Hairpin's icon holds the items.
    var usesButton: Bool { !entries.isEmpty && anchor?.place == .button }

    /// Hairpin's own icon, which opens the items while it's the leftmost one.
    func attach(to button: NSStatusBarButton) {
        self.button = button
        button.addTrackingArea(NSTrackingArea(rect: .zero,
                                              options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                              owner: self, userInfo: nil))
    }

    func update(_ entries: [StackEntry], anchor: StackAnchor?) {
        guard entries != self.entries || anchor != self.anchor else { return }
        let changed = entries != self.entries
        self.entries = entries
        self.anchor = anchor
        guard !entries.isEmpty, let anchor else {
            hide()
            return
        }
        switch anchor.place {
        case let .slot(minX, width):
            let pile = self.pile ?? makePanel()
            self.pile = pile
            pile.appearance = appearance
            if changed { label(pile) }
            pile.setFrame(NSRect(x: minX, y: anchor.row.minY, width: width, height: anchor.row.height), display: true)
            pile.orderFrontRegardless()
        case .button:
            pile?.orderOut(nil)
        }
        if isExpanded { showList(animated: false) }
    }

    /// Opens the row; `pinned` keeps it open when the pointer leaves.
    func expand(pinned: Bool = false) {
        expandTimer?.invalidate()
        expandTimer = nil
        guard !isExpanded, !entries.isEmpty, pile?.isVisible == true || usesButton else { return }
        onExpand?()
        isExpanded = true
        isPinned = pinned
        showList(animated: true)
        watchClicks()
    }

    /// A click on the pin: opens the row to stay, or closes it.
    func toggle() {
        if isExpanded { collapse() } else { expand(pinned: true) }
    }

    func collapse() {
        expandTimer?.invalidate()
        expandTimer = nil
        collapseTimer?.invalidate()
        collapseTimer = nil
        guard isExpanded else { return }
        isExpanded = false
        isPinned = false
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
            MainActor.assumeIsolated { self?.expand() }
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
        isPinned = true
        collapseTimer?.invalidate()
        collapseTimer = nil
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

    /// Draws the pin once and labels it with the count.
    private func label(_ pile: NSPanel) {
        guard let content = pile.contentView else { return }
        if content.subviews.isEmpty {
            let view = NSImageView(image: HairpinIcon.image(side: Self.pinSide))
            view.frame = content.bounds
            view.autoresizingMask = [.width, .height]
            view.imageAlignment = .alignCenter
            content.addSubview(view)
        }
        (content.subviews.first as? NSImageView)?.contentTintColor = foreground
        content.toolTip = entries.count == 1 ? "1 hidden icon" : "\(entries.count) hidden icons"
        content.setAccessibilityLabel(content.toolTip)
    }

    /// The hidden items in a row of glass under the pin, in menu bar order,
    /// icons as they look in the menu bar.
    private func showList(animated: Bool) {
        guard let anchor, let opener = (usesButton ? button?.window : pile) else { return }
        let list = self.list ?? makeList()
        self.list = list

        let items = entries.map { entry in
            GlassItem(image: Self.fitted(entry.image, side: Self.iconSide), toolTip: entry.toolTip,
                      side: Self.cellSide) { [weak self] in self?.select(entry.id) }
        }
        let row = NSStackView(views: items)
        row.orientation = .horizontal
        row.spacing = Self.cellSpacing
        row.edgeInsets = NSEdgeInsets(top: Self.listInset, left: Self.listInset,
                                      bottom: Self.listInset, right: Self.listInset)
        let size = row.fittingSize
        row.frame = NSRect(origin: .zero, size: size)
        let background = Self.glass(around: row, cornerRadius: size.height / 2)
        background.frame = row.frame
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
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor.row) }?.frame ?? anchor.row
        let x = min(max(opener.frame.midX - size.width / 2, screen.minX + 6), screen.maxX - size.width - 6)
        let frame = NSRect(x: x, y: anchor.row.minY - Self.listGap - size.height, width: size.width, height: size.height)
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
