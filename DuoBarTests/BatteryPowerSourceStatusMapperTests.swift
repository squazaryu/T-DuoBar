import IOKit.ps
import XCTest
@testable import DuoBar

final class BatteryPowerSourceStatusMapperTests: XCTestCase {
    func testUPSAndAdapterCannotBecomeAnInternalBattery() {
        let ups: [String: Any] = ["Type": "UPS", kIOPSCurrentCapacityKey: 80, kIOPSMaxCapacityKey: 100]
        XCTAssertNil(BatteryPowerSourceStatusMapper.internalBattery(in: [ups]))
        XCTAssertEqual(map(ups), .unavailable)
        let internalSource = source()
        XCTAssertEqual(BatteryPowerSourceStatusMapper.internalBattery(in: [ups, internalSource])?["Type"] as? String,
                       kIOPSInternalBatteryType)
    }

    func testRoundedHundredDoesNotInventFullCharge() {
        var dictionary = source()
        dictionary[kIOPSCurrentCapacityKey] = 999
        dictionary[kIOPSMaxCapacityKey] = 1000
        XCTAssertEqual(map(dictionary).percentage, 100)
        XCTAssertFalse(map(dictionary).isFullyCharged)
        dictionary[kIOPSIsChargedKey] = false
        XCTAssertFalse(map(dictionary).isFullyCharged)
        dictionary[kIOPSIsChargedKey] = true
        XCTAssertTrue(map(dictionary).isFullyCharged)
    }

    func testAuthoritativeFullChargeAndExistingDetailsArePreserved() {
        var dictionary = source()
        dictionary[kIOPSCurrentCapacityKey] = 99
        dictionary[kIOPSIsChargedKey] = true
        dictionary[kIOPSTimeToEmptyKey] = 120
        dictionary[kIOPSTimeToFullChargeKey] = 45
        let status = BatteryPowerSourceStatusMapper.status(dictionary: dictionary, adapterWatts: 67, lowPowerModeEnabled: true)
        XCTAssertTrue(status.isFullyCharged)
        XCTAssertTrue(status.isLowPowerModeEnabled)
        XCTAssertEqual(status.adapterWatts, 67)
        XCTAssertEqual(status.timeToEmptyMinutes, 120)
        XCTAssertEqual(status.timeToFullChargeMinutes, 45)
        dictionary[kIOPSPowerSourceStateKey] = kIOPSBatteryPowerValue
        XCTAssertNil(map(dictionary).adapterWatts)
    }

    func testInvalidCapacityAndAdapterReadingsAreHandledSafely() {
        for (current, maximum, expected): (Int, Int, Int?) in [(-1, 100, nil), (50, 0, nil), (50, -1, nil),
                                                             (Int.max, 1, 100), (0, 100, 0), (1, 3, 33)] {
            var dictionary = source()
            dictionary[kIOPSCurrentCapacityKey] = current
            dictionary[kIOPSMaxCapacityKey] = maximum
            XCTAssertEqual(map(dictionary).percentage, expected)
        }
        for watts in [-1, 0, 1001] {
            XCTAssertNil(BatteryPowerSourceStatusMapper.status(dictionary: source(), adapterWatts: watts,
                                                             lowPowerModeEnabled: false).adapterWatts)
        }
    }

    private func source() -> [String: Any] {
        ["Type": kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: 100, kIOPSMaxCapacityKey: 100,
         kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: false]
    }
    private func map(_ dictionary: [String: Any]) -> BatteryStatus {
        BatteryPowerSourceStatusMapper.status(dictionary: dictionary, adapterWatts: 67, lowPowerModeEnabled: false)
    }
}
