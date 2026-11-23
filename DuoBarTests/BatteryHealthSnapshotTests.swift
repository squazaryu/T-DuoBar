import XCTest
@testable import DuoBar

final class BatteryHealthSnapshotTests: XCTestCase {
    func testAppleSiliconUsesNestedNominalCapacityAheadOfRawCapacity() {
        let properties: [String: Any] = [
            "BatteryInstalled": true,
            "CycleCount": 207,
            "MaxCapacity": 100,
            "BatteryData": [
                "DesignCapacity": 6249,
                "NominalChargeCapacity": 5601,
                "AppleRawMaxCapacity": 5449,
                "MaxCapacity": 100
            ]
        ]

        XCTAssertEqual(decode(properties), .init(maximumCapacityPercentage: 90, cycleCount: 207))
    }

    func testValidRawCapacityCanReplaceInvalidNominalCapacity() {
        let properties: [String: Any] = [
            "DesignCapacity": 6000,
            "NominalChargeCapacity": 0,
            "AppleRawMaxCapacity": 4500,
            "CurrentCapacity": 1000
        ]

        XCTAssertEqual(decode(properties), .init(maximumCapacityPercentage: 75, cycleCount: nil))
    }

    func testCapacityAndDesignMustComeFromTheSameGaugeRepresentation() {
        let properties: [String: Any] = [
            "DesignCapacity": 6000,
            "BatteryData": ["NominalChargeCapacity": 5500, "CycleCount": 15]
        ]

        XCTAssertEqual(decode(properties), .init(maximumCapacityPercentage: nil, cycleCount: 15))
    }

    func testOnlyIntelCanUseAnUnnormalizedLegacyMaximum() {
        let properties = ["DesignCapacity": 6000, "MaxCapacity": 4800, "CycleCount": 0]
        let normalized = ["DesignCapacity": 6000, "MaxCapacity": 100, "CycleCount": 0]

        XCTAssertEqual(decode(properties, allowsLegacyMaximum: true),
                       .init(maximumCapacityPercentage: 80, cycleCount: 0))
        XCTAssertEqual(decode(properties), .init(maximumCapacityPercentage: nil, cycleCount: 0))
        XCTAssertEqual(decode(normalized, allowsLegacyMaximum: true),
                       .init(maximumCapacityPercentage: nil, cycleCount: 0))
    }

    func testFieldsRemainIndependentWhenGaugeValuesAreMissingOrMalformed() {
        XCTAssertEqual(decode([:]), .unavailable)
        for invalid: Any in [true, "12", 2.5, -1, Double.nan, Double.infinity, UInt16.max, UInt64.max] {
            XCTAssertEqual(decode(["CycleCount": invalid, "DesignCapacity": 5000, "NominalChargeCapacity": 5100]),
                           .init(maximumCapacityPercentage: 102, cycleCount: nil))
            XCTAssertEqual(decode(["CycleCount": 200, "DesignCapacity": 5000, "NominalChargeCapacity": invalid]),
                           .init(maximumCapacityPercentage: nil, cycleCount: 200))
        }
        for invalidDesign in [0, 100, -5000] {
            XCTAssertEqual(decode(["DesignCapacity": invalidDesign, "NominalChargeCapacity": 4500]), .unavailable)
        }
        XCTAssertEqual(decode(["DesignCapacity": 5000, "NominalChargeCapacity": 10000]), .unavailable)
    }

    func testExplicitlyMissingOrMalformedBatteryInstallationSuppressesOtherFields() {
        XCTAssertEqual(decode(["BatteryInstalled": false, "CycleCount": 5]), .unavailable)
        XCTAssertEqual(decode(["BatteryInstalled": "Yes", "CycleCount": 5]), .unavailable)
    }

    private func decode(_ properties: [String: Any], allowsLegacyMaximum: Bool = false) -> BatteryHealthSnapshot {
        BatteryHealthSnapshot.decode(properties, allowsLegacyMaximum: allowsLegacyMaximum)
    }
}
