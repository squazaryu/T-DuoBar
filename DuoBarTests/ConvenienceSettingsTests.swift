import AppKit
import XCTest
@testable import DuoBar

final class ConvenienceSettingsTests: XCTestCase {
    func testLanguageResourcesResolveIndependentlyOfSystemLanguage() {
        XCTAssertEqual(AppLocalization.string("Settings", language: .english), "Settings")
        XCTAssertEqual(AppLocalization.string("Settings", language: .german), "Einstellungen")
        XCTAssertEqual(AppLocalization.string("Settings", language: .russian), "Настройки")
        XCTAssertEqual(AppLocalization.string("Settings", language: .ukrainian), "Параметри")
        XCTAssertNotEqual(AppLocalization.string("Settings", language: .simplifiedChinese), "Settings")
        XCTAssertNotEqual(AppLocalization.string("Settings", language: .traditionalChinese), "Settings")
        XCTAssertEqual(AppLocalization.string("Unknown translation key", language: .russian), "Unknown translation key")
        XCTAssertNil(AppLanguage(rawValue: "../../unsupported"))
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue).count, 7)
    }

    func testAutoHideOnlyHidesEmptySuccessfulResultsAndKeepsRecoveryVisible() {
        XCTAssertTrue(AccessorySectionVisibility.showsSection(hideEmpty: false, deviceCount: 0, hasError: false))
        XCTAssertFalse(AccessorySectionVisibility.showsSection(hideEmpty: true, deviceCount: 0, hasError: false))
        XCTAssertTrue(AccessorySectionVisibility.showsSection(hideEmpty: true, deviceCount: 1, hasError: false))
        XCTAssertTrue(AccessorySectionVisibility.showsSection(hideEmpty: true, deviceCount: 0, hasError: true))
    }

    func testDiscreteVolumeStepsAndNaturalScrolling() {
        var scroll = VolumeScrollAccumulator()
        XCTAssertEqual(scroll.change(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 1, deviceUID: "a"), 0.02)
        XCTAssertEqual(scroll.change(deltaY: -1, precise: false, inverted: false, momentum: false, timestamp: 1.1, deviceUID: "a"), -0.02)
        XCTAssertEqual(scroll.change(deltaY: -1, precise: false, inverted: true, momentum: false, timestamp: 1.2, deviceUID: "a"), 0.02)
    }

    func testPreciseInputAccumulatesAndIgnoresMomentum() {
        var scroll = VolumeScrollAccumulator()
        for index in 0..<3 {
            XCTAssertNil(scroll.change(deltaY: 3, precise: true, inverted: false, momentum: false,
                timestamp: 1 + Double(index) * 0.01, deviceUID: "a"))
        }
        XCTAssertEqual(scroll.change(deltaY: 3, precise: true, inverted: false, momentum: false, timestamp: 1.04, deviceUID: "a"), 0.02)
        XCTAssertNil(scroll.change(deltaY: 60, precise: true, inverted: false, momentum: true, timestamp: 1.05, deviceUID: "a"))
    }

    func testFractionsDoNotLeakAcrossDirectionDeviceOrGestureChanges() {
        var scroll = VolumeScrollAccumulator()
        XCTAssertNil(scroll.change(deltaY: 10, precise: true, inverted: false, momentum: false, timestamp: 1, deviceUID: "a"))
        XCTAssertNil(scroll.change(deltaY: -3, precise: true, inverted: false, momentum: false, timestamp: 1.01, deviceUID: "a"))
        XCTAssertEqual(scroll.change(deltaY: -9, precise: true, inverted: false, momentum: false, timestamp: 1.02, deviceUID: "a"), -0.02)
        XCTAssertNil(scroll.change(deltaY: 10, precise: true, inverted: false, momentum: false, timestamp: 1.1, deviceUID: "a"))
        XCTAssertNil(scroll.change(deltaY: 3, precise: true, inverted: false, momentum: false, timestamp: 1.2, deviceUID: "b"))
        XCTAssertNil(scroll.change(deltaY: 10, precise: true, inverted: false, momentum: false, timestamp: 2, deviceUID: "b"))
        XCTAssertNil(scroll.change(deltaY: 3, precise: true, inverted: false, momentum: false, timestamp: 2.1, deviceUID: "b", beginsGesture: true))
    }

    func testAcceleratedAndInvalidInputCannotProduceAnUnboundedJump() {
        var scroll = VolumeScrollAccumulator()
        XCTAssertNil(scroll.change(deltaY: .nan, precise: false, inverted: false, momentum: false, timestamp: 1, deviceUID: "a"))
        XCTAssertNil(scroll.change(deltaY: .infinity, precise: false, inverted: false, momentum: false, timestamp: 1, deviceUID: "a"))
        XCTAssertEqual(scroll.change(deltaY: 1e100, precise: false, inverted: false, momentum: false, timestamp: 1, deviceUID: "a"), 0.1)
        XCTAssertEqual(scroll.change(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 1.1, deviceUID: "a"), 0.02)
    }

    @MainActor
    func testScrollSettingIsOptInAndMonitorIsRemovedWhenDisabledOrInvalidated() async throws {
        let suite = "ConvenienceSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SystemStatusStore(startServices: false)
        store.applyDebugAudioDeviceState(.builtIn)
        store.applyDebugVolumeState(.fifty)
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        XCTAssertFalse(controller.hasVolumeScrollMonitor)
        XCTAssertFalse(controller.handleVolumeScroll(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 1))
        XCTAssertEqual(store.status.audio.volume.level, 0.5)

        defaults.set(true, forKey: PreferenceKeys.scrollToAdjustVolume)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        for _ in 0..<50 where !controller.hasVolumeScrollMonitor { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(controller.hasVolumeScrollMonitor)
        XCTAssertTrue(controller.handleVolumeScroll(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 1))
        XCTAssertEqual(try XCTUnwrap(store.status.audio.volume.level), 0.52, accuracy: 0.0001)
        store.applyDebugVolumeState(.muted)
        _ = controller.handleVolumeScroll(deltaY: -1, precise: false, inverted: false, momentum: false, timestamp: 1.1)
        XCTAssertTrue(store.status.audio.volume.isMuted)
        _ = controller.handleVolumeScroll(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 1.2)
        XCTAssertFalse(store.status.audio.volume.isMuted)
        XCTAssertEqual(try XCTUnwrap(store.status.audio.volume.level), 0.02, accuracy: 0.0001)
        store.applyDebugVolumeState(.controlledByDevice)
        XCTAssertFalse(controller.handleVolumeScroll(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 1.3))

        defaults.set(false, forKey: PreferenceKeys.scrollToAdjustVolume)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        for _ in 0..<50 where controller.hasVolumeScrollMonitor { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(controller.hasVolumeScrollMonitor)
        defaults.set(true, forKey: PreferenceKeys.scrollToAdjustVolume)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        for _ in 0..<50 where !controller.hasVolumeScrollMonitor { try await Task.sleep(for: .milliseconds(10)) }
        controller.invalidate()
        XCTAssertFalse(controller.hasVolumeScrollMonitor)
        XCTAssertFalse(controller.handleVolumeScroll(deltaY: 1, precise: false, inverted: false, momentum: false, timestamp: 2))
    }

    @MainActor
    func testAutoHiddenEmptySectionDoesNotStopDiscoveryWhileThePopoverIsOpen() async throws {
        let suite = "HiddenAccessoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: PreferenceKeys.hideEmptyAccessories)
        defaults.set(false, forKey: PreferenceKeys.showVPN)
        let service = AccessoryBatteryService(reportReader: { [] })
        let store = SystemStatusStore(startServices: false, accessoryBatteryService: service)
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification))
        for _ in 0..<50 where service.isRefreshing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(service.isPolling)
        XCTAssertTrue(service.accessories.isEmpty)
        controller.popoverWillClose(Notification(name: NSPopover.willCloseNotification))
        XCTAssertFalse(service.isPolling)
    }
}
