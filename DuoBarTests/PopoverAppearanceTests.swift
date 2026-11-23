import AppKit
import XCTest
@testable import DuoBar

final class PopoverAppearanceTests: XCTestCase {
    @MainActor
    func testGlassSelectionUsesARealGlassSurfaceAndClassicRestoresPopover() async throws {
        guard #available(macOS 26.0, *), !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else {
            throw XCTSkip("Requires native glass without the accessibility override")
        }
        let name = "PopoverAppearanceTests.Live.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("liquidGlass", forKey: PreferenceKeys.popoverStyle)
        defaults.set(false, forKey: PreferenceKeys.animationsEnabled)
        defaults.set(false, forKey: PreferenceKeys.showNetwork)
        defaults.set(true, forKey: PreferenceKeys.showVPN)
        defaults.set(false, forKey: PreferenceKeys.showAccessories)
        let vpn = VPNStatusService(reader: { VPNStatus(connections: []) }, monitor: TestVPNChangeMonitor())
        let store = SystemStatusStore(startServices: false, vpnStatusService: vpn)
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        let anchorWindow = NSWindow(contentRect: NSRect(x: 300, y: 600, width: 30, height: 30),
            styleMask: [.borderless], backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        anchorWindow.contentView = anchor
        anchorWindow.orderFrontRegardless()
        defer { anchorWindow.orderOut(nil) }
        controller.previewPopover(relativeTo: anchor)
        let glassWindow = try XCTUnwrap(controller.menuWindow, "The glass menu should be visible")
        XCTAssertTrue(glassWindow is GlassPopoverPanel, "Glass selection must change the actual presentation, not just tint the old popover")
        XCTAssertFalse(glassWindow.isOpaque)
        XCTAssertTrue(glassWindow.contentView is NSGlassEffectView)
        XCTAssertTrue(try XCTUnwrap(glassWindow as? GlassPopoverPanel).hasClickMonitors)
        let retainedContent = (glassWindow.contentView as? NSGlassEffectView)?.contentView
        XCTAssertTrue(vpn.isMonitoring)
        XCTAssertTrue(store.isPopoverVisible)
        controller.popoverWillClose(Notification(name: NSPopover.willCloseNotification))
        controller.popoverDidClose(Notification(name: NSPopover.didCloseNotification))
        XCTAssertTrue(vpn.isMonitoring, "A late close from the old popover must not stop a visible glass panel")
        XCTAssertTrue(store.isPopoverVisible)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        for _ in 0..<40 where store.isPopoverVisible { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isPopoverVisible)
        XCTAssertTrue(glassWindow.isVisible, "Display sleep pauses readings without closing the panel")
        workspace.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        for _ in 0..<40 where !store.isPopoverVisible { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(store.isPopoverVisible)
        let background = try XCTUnwrap(findBackground(in: try XCTUnwrap(glassWindow.contentView)))
        XCTAssertEqual(background.fillOpacity, 0.35, accuracy: 0.0001)
        defaults.set(0.2, forKey: PreferenceKeys.popoverTransparency)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        for _ in 0..<50 where abs(background.fillOpacity - 0.8) > 0.0001 { try await Task.sleep(for: .milliseconds(10)) }
        background.displayIfNeeded()
        XCTAssertEqual(background.fillOpacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(background.layer?.backgroundColor).alpha, 0.8, accuracy: 0.0001)
        XCTAssertEqual(glassWindow.alphaValue, 1)
        (glassWindow as? GlassPopoverPanel)?.dismiss()
        XCTAssertFalse(vpn.isMonitoring)
        XCTAssertFalse(store.isPopoverVisible)
        XCTAssertFalse(try XCTUnwrap(glassWindow as? GlassPopoverPanel).hasClickMonitors)
        defaults.set("classic", forKey: PreferenceKeys.popoverStyle)
        defaults.set(false, forKey: PreferenceKeys.showVPN)
        controller.previewPopover(relativeTo: anchor)
        let classicWindow = try XCTUnwrap(controller.menuWindow, "The classic menu should be visible")
        XCTAssertFalse(classicWindow is GlassPopoverPanel)
        XCTAssertTrue(store.isPopoverVisible)
        XCTAssertEqual(background.fillOpacity, 1)
        XCTAssertTrue(retainedContent?.window === classicWindow, "Switching styles must reuse the content and its state")
        XCTAssertFalse(store.vpnStatusService.isMonitoring)
        XCTAssertFalse(store.accessoryBatteryService.isPolling)
    }

    @MainActor
    private func findBackground(in view: NSView) -> PopoverBackgroundView? {
        if let background = view as? PopoverBackgroundView { return background }
        return view.subviews.lazy.compactMap { self.findBackground(in: $0) }.first
    }

    @MainActor
    func testGlassPanelDismissesOnceOnEscapeAndReleasesEventMonitors() {
        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 40, height: 30),
            styleMask: [.borderless], backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        anchorWindow.contentView = anchor
        anchorWindow.orderFrontRegardless()
        defer { anchorWindow.orderOut(nil) }
        let panel = GlassPopoverPanel()
        let content = NSViewController()
        content.view = NSView(frame: NSRect(x: 0, y: 0, width: 304, height: 200))
        panel.setHostedController(content)
        var events: [String] = []
        panel.onShow = { events.append("shown") }
        panel.onWillClose = { events.append("will-close") }
        panel.onClose = { events.append("closed") }
        panel.show(relativeTo: anchor, contentSize: NSSize(width: 304, height: 200))
        XCTAssertTrue(panel.isVisible)
        XCTAssertTrue(panel.hasClickMonitors)
        panel.cancelOperation(nil)
        panel.dismiss()
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(panel.hasClickMonitors)
        XCTAssertEqual(events, ["shown", "will-close", "closed"])
        panel.setHostedController(nil)
        XCTAssertNil(content.parent)
        XCTAssertNil(content.view.superview)
    }

    @MainActor
    func testGlassPanelPlacementFitsSecondaryScreenAndKeepsTopWhenExpanded() {
        let screen = NSRect(x: -1440, y: 0, width: 1440, height: 850)
        let anchor = NSRect(x: -45, y: 850, width: 24, height: 24)
        let compact = GlassPopoverPanel.frame(contentSize: NSSize(width: 304, height: 316), anchor: anchor, visibleFrame: screen)
        let expanded = GlassPopoverPanel.frame(contentSize: NSSize(width: 304, height: 600), anchor: anchor, visibleFrame: screen)
        XCTAssertTrue(screen.contains(compact))
        XCTAssertTrue(screen.contains(expanded))
        XCTAssertEqual(compact.maxY, expanded.maxY)
        XCTAssertEqual(compact.maxX, screen.maxX - 6)
        let leftEdge = GlassPopoverPanel.frame(contentSize: NSSize(width: 304, height: 316),
            anchor: NSRect(x: -1440, y: 850, width: 24, height: 24), visibleFrame: screen)
        XCTAssertEqual(leftEdge.minX, screen.minX + 6)
    }

    func testUnknownStyleAndMissingPreferencesFallBackToClassic() {
        XCTAssertEqual(PopoverAppearance(styleRaw: "future-style").style, .classic)
        let name = "PopoverAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let appearance = PopoverAppearance(defaults: defaults)
        XCTAssertEqual(appearance.style, .classic)
        XCTAssertEqual(appearance.transparency, 0.65)
        defaults.set("invalid", forKey: PreferenceKeys.popoverTransparency)
        XCTAssertEqual(PopoverAppearance(defaults: defaults).transparency, 0.65)
    }

    func testTransparencyClampsAndRejectsNonFiniteValues() {
        XCTAssertEqual(PopoverAppearance.resolveTransparency(-1), 0)
        XCTAssertEqual(PopoverAppearance.resolveTransparency(2), 1)
        XCTAssertEqual(PopoverAppearance.resolveTransparency(0.45), 0.45)
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(PopoverAppearance.resolveTransparency(invalid), PopoverAppearance.defaultTransparency)
        }
    }

    func testGlassTransparencyAndOpaqueFallbacks() {
        let glass = PopoverAppearance(styleRaw: "liquidGlass", transparency: 0.8)
        XCTAssertEqual(glass.backgroundOpacity(supportsLiquidGlass: true, reduceTransparency: false), 0.2, accuracy: 0.0001)
        XCTAssertEqual(glass.backgroundOpacity(supportsLiquidGlass: false, reduceTransparency: false), 1)
        XCTAssertEqual(glass.backgroundOpacity(supportsLiquidGlass: true, reduceTransparency: true), 1)
        let classic = PopoverAppearance(styleRaw: "classic", transparency: 1)
        XCTAssertEqual(classic.backgroundOpacity(supportsLiquidGlass: true, reduceTransparency: false), 1)
    }

    func testStoredAppearanceRoundTripsWithoutChangingOtherPreferences() {
        let name = "PopoverAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("liquidGlass", forKey: PreferenceKeys.popoverStyle)
        defaults.set(0.75, forKey: PreferenceKeys.popoverTransparency)
        defaults.set(false, forKey: PreferenceKeys.showVPN)
        let appearance = PopoverAppearance(defaults: defaults)
        XCTAssertEqual(appearance.style, .liquidGlass)
        XCTAssertEqual(appearance.transparency, 0.75)
        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.showVPN))
    }

    @MainActor
    func testBackgroundOpacityDoesNotAffectControlsOrInterceptClicks() {
        let background = PopoverBackgroundView(frame: NSRect(x: 0, y: 0, width: 304, height: 100))
        let container = NSView(frame: background.frame)
        let control = NSButton(title: "Settings", target: nil, action: nil)
        control.frame = NSRect(x: 12, y: 12, width: 100, height: 30)
        container.addSubview(background)
        container.addSubview(control)
        for opacity in [0.0, 0.35, 1.0] {
            background.fillOpacity = opacity
            XCTAssertEqual(container.alphaValue, 1)
            XCTAssertEqual(control.alphaValue, 1)
            XCTAssertNil(background.hitTest(NSPoint(x: 20, y: 20)))
            XCTAssertEqual(background.isOpaque, opacity == 1)
        }
    }
}
