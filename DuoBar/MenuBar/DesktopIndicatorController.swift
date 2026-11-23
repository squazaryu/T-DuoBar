import AppKit
import ColorSync
import SwiftUI

/// A desktop-level, nonactivating panel, inspired by the MIT-licensed desktop
/// widget in Mikeli7666/DuoBar v1.4.2. It shares the app's live status store.
@MainActor
final class DesktopIndicatorController {
    private static let placementKey = "desktopIndicator.placement"

    private let statusStore: SystemStatusStore
    private let defaults: UserDefaults
    private var size = DesktopIndicatorSize.defaultSize
    private var placement: DesktopIndicatorPlacement?
    private var panel: DesktopIndicatorPanel?
    private var defaultsObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    init(statusStore: SystemStatusStore, defaults: UserDefaults = .standard) {
        self.statusStore = statusStore
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.placementKey) {
            placement = try? PropertyListDecoder().decode(DesktopIndicatorPlacement.self, from: data)
        }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyPreferences() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: NSApp, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.defaultsObserver != nil else { return }
                self.updatePanelPlacement()
            }
        }
        applyPreferences()
    }

    func invalidate() {
        removeObservers()
        removePanel()
    }

    private func applyPreferences() {
        guard defaultsObserver != nil else { return }
        guard defaults.bool(forKey: PreferenceKeys.showDesktopIndicator) else {
            removePanel()
            return
        }
        let preferredSize = DesktopIndicatorSize.resolve(defaults.string(forKey: PreferenceKeys.desktopIndicatorSize))
        if size != preferredSize || panel == nil {
            size = preferredSize
            updatePanelPlacement()
        }
        let title = localized("Desktop status indicator")
        if panel?.title != title { panel?.title = title }
    }

    private func updatePanelPlacement() {
        guard defaults.bool(forKey: PreferenceKeys.showDesktopIndicator) else { return }
        guard let frame = DesktopIndicatorPlacement.frame(size: size, placement: placement, screens: Self.screens) else {
            removePanel()
            return
        }

        let panel = panel ?? makePanel(frame: frame)
        self.panel = panel
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func makePanel(frame: NSRect) -> DesktopIndicatorPanel {
        let panel = DesktopIndicatorPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.title = localized("Desktop status indicator")
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.isMovable = false
        panel.animationBehavior = .none

        let content = DesktopIndicatorView(statusStore: statusStore).defaultAppStorage(defaults)
        let hosting = DesktopIndicatorHostingView(rootView: content)
        hosting.sizingOptions = []
        hosting.onDragEnded = { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel else { return }
            self.savePlacement(for: panel)
        }
        panel.contentView = hosting
        return panel
    }

    private func savePlacement(for panel: DesktopIndicatorPanel) {
        guard let placement = DesktopIndicatorPlacement.capture(frame: panel.frame, screens: Self.screens) else { return }
        self.placement = placement
        if let data = try? PropertyListEncoder().encode(placement) {
            defaults.set(data, forKey: Self.placementKey)
        }
        updatePanelPlacement()
    }

    private func removePanel() {
        guard let panel else { return }
        self.panel = nil
        panel.orderOut(nil)
        panel.contentView = nil
        panel.close()
    }

    private func removeObservers() {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        defaultsObserver = nil
        screenObserver = nil
    }

    private static var screens: [DesktopIndicatorScreen] {
        NSScreen.screens.compactMap { screen in
            guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  !screen.visibleFrame.isEmpty else { return nil }
            let displayID = CGDirectDisplayID(displayNumber.uint32Value)
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
            let identifier = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? displayNumber.stringValue
            return DesktopIndicatorScreen(id: identifier, visibleFrame: screen.visibleFrame)
        }
    }

    deinit {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
}

private final class DesktopIndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class DesktopIndicatorHostingView<Content: View>: NSHostingView<Content> {
    var onDragEnded: (() -> Void)?
    private var startPointer: NSPoint?
    private var startOrigin = NSPoint.zero
    private var moved = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // The entire face is a drag surface. Route its mouse events here while
    // keeping the SwiftUI hierarchy available to accessibility clients.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startPointer = NSEvent.mouseLocation
        startOrigin = window.frame.origin
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let startPointer else { return }
        let pointer = NSEvent.mouseLocation
        let dx = pointer.x - startPointer.x
        let dy = pointer.y - startPointer.y
        guard moved || hypot(dx, dy) >= 4 else { return }
        moved = true
        window.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        startPointer = nil
        if moved {
            moved = false
            onDragEnded?()
        }
    }
}
