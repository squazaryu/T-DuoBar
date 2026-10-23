import AppKit
import XCTest
@testable import DuoBar

final class StatusTooltipTests: XCTestCase {
    @MainActor
    func testStatusItemHasNoTooltipAfterBatteryOrPreferenceChanges() async throws {
        let suite = "StatusTooltipTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SystemStatusStore(startServices: false, deviceContext: DeviceContext(hasInternalBattery: true))
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }

        XCTAssertNil(controller.tooltipText)
        for charging in [false, true] {
            store.applyDebugBatteryStatus(BatteryStatus(percentage: 68, isCharging: charging,
                isPluggedIn: charging, isFullyCharged: false, isAvailable: true,
                timeToEmptyMinutes: 260, timeToFullChargeMinutes: 45))
            defaults.set(charging, forKey: PreferenceKeys.showBatteryTime)
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
            try await Task.sleep(for: .milliseconds(20))
            XCTAssertNil(controller.tooltipText)
        }
        store.applyDebugBatteryStatus(.unavailable)
        XCTAssertNil(controller.tooltipText)
        XCTAssertFalse(store.accessoryBatteryService.isPolling)
    }
}
