import AppKit
import XCTest
@testable import DuoBar

final class DesktopIndicatorTests: XCTestCase {
    private let primary = DesktopIndicatorScreen(id: "primary", visibleFrame: CGRect(x: 0, y: 65, width: 1440, height: 785))
    private let secondary = DesktopIndicatorScreen(id: "secondary", visibleFrame: CGRect(x: -1280, y: 200, width: 1280, height: 720))

    func testSizesAndDefaultPlacement() throws {
        XCTAssertEqual(DesktopIndicatorSize.resolve(nil), .medium)
        XCTAssertEqual(DesktopIndicatorSize.resolve("obsolete"), .medium)
        XCTAssertEqual(DesktopIndicatorSize.allCases.map(\.edge), [64, 84, 108])
        XCTAssertNil(DesktopIndicatorPlacement.frame(size: .medium, placement: nil, screens: []))
        let frame = try XCTUnwrap(DesktopIndicatorPlacement.frame(size: .medium, placement: nil, screens: [primary, secondary]))
        XCTAssertEqual(frame.maxX, primary.visibleFrame.maxX - 18)
        XCTAssertEqual(frame.maxY, primary.visibleFrame.maxY - 18)
    }

    func testUntilReconnectedUsesPrimaryAndKeepsSecondaryAnchor() throws {
        let droppedFrame = CGRect(x: -400, y: 880, width: 64, height: 64)
        let placement = try XCTUnwrap(DesktopIndicatorPlacement.capture(frame: droppedFrame, screens: [primary, secondary]))
        XCTAssertEqual(placement.screenID, secondary.id)
        XCTAssertEqual(placement.y, 1)

        let fallback = try XCTUnwrap(DesktopIndicatorPlacement.frame(size: .large, placement: placement, screens: [primary]))
        XCTAssertTrue(primary.visibleFrame.contains(fallback))
        XCTAssertEqual(fallback.maxY, primary.visibleFrame.maxY)

        let restored = try XCTUnwrap(DesktopIndicatorPlacement.frame(size: .large, placement: placement, screens: [primary, secondary]))
        XCTAssertTrue(secondary.visibleFrame.contains(restored))
        XCTAssertEqual(restored.maxY, secondary.visibleFrame.maxY)
    }

    func testDropInGapUsesNearestDisplayAndClampsOversizePanel() throws {
        let small = DesktopIndicatorScreen(id: "small", visibleFrame: CGRect(x: 1600, y: 100, width: 60, height: 70))
        let placement = try XCTUnwrap(DesktopIndicatorPlacement.capture(
            frame: CGRect(x: 1500, y: 100, width: 64, height: 64), screens: [primary, small]
        ))
        XCTAssertEqual(placement.screenID, small.id)

        let frame = try XCTUnwrap(DesktopIndicatorPlacement.frame(size: .large, placement: placement, screens: [primary, small]))
        XCTAssertEqual(frame.size, CGSize(width: 60, height: 60))
        XCTAssertTrue(small.visibleFrame.contains(frame))
    }

    @MainActor
    func testPanelLivesOnlyWhileEnabledAndDoesNotOwnMonitoring() async throws {
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("Desktop panel needs a screen") }
        let suite = "DesktopIndicatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SystemStatusStore(startServices: false)
        let ownerCount = AdaptiveRingMonitor.shared.monitoringOwnerCount
        let previousKeyWindow = NSApp.keyWindow
        let controller = DesktopIndicatorController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        let title = localized("Desktop status indicator")
        func currentPanel() -> NSWindow? {
            NSApp.windows.first { $0.title == title }
        }
        XCTAssertNil(currentPanel())

        defaults.set(true, forKey: PreferenceKeys.showDesktopIndicator)
        for _ in 0..<30 where currentPanel() == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        let panel = try XCTUnwrap(currentPanel())
        XCTAssertTrue(panel.isVisible)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertLessThan(panel.level.rawValue, NSWindow.Level.normal.rawValue)
        XCTAssertTrue(NSApp.keyWindow === previousKeyWindow)
        XCTAssertEqual(AdaptiveRingMonitor.shared.monitoringOwnerCount, ownerCount)

        defaults.set(DesktopIndicatorSize.small.rawValue, forKey: PreferenceKeys.desktopIndicatorSize)
        for _ in 0..<30 where panel.frame.width != DesktopIndicatorSize.small.edge {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(panel.frame.width, DesktopIndicatorSize.small.edge)
        XCTAssertTrue(currentPanel() === panel)

        defaults.set(false, forKey: PreferenceKeys.showDesktopIndicator)
        for _ in 0..<30 where panel.isVisible {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(panel.contentView)
        XCTAssertEqual(AdaptiveRingMonitor.shared.monitoringOwnerCount, ownerCount)
    }
}
