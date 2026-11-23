import Foundation

struct BatteryHealthSnapshot: Equatable, Sendable {
    let maximumCapacityPercentage: Int?
    let cycleCount: Int?

    static let unavailable = Self(maximumCapacityPercentage: nil, cycleCount: nil)

    static func decode(_ properties: [String: Any], allowsLegacyMaximum: Bool) -> Self {
        if let value = properties["BatteryInstalled"] {
            guard let installed = value as? NSNumber,
                  CFGetTypeID(installed) == CFBooleanGetTypeID(), installed.boolValue else {
                return .unavailable
            }
        }

        let batteryData = properties["BatteryData"] as? [String: Any] ?? [:]
        let nominal = capacityPercentage(in: properties, maximumKey: "NominalChargeCapacity")
            ?? capacityPercentage(in: batteryData, maximumKey: "NominalChargeCapacity")
        let raw = capacityPercentage(in: properties, maximumKey: "AppleRawMaxCapacity")
            ?? capacityPercentage(in: batteryData, maximumKey: "AppleRawMaxCapacity")
        // MaxCapacity can instead be the normalized denominator for state of charge.
        let legacy = allowsLegacyMaximum ? capacityPercentage(in: properties, maximumKey: "MaxCapacity") : nil

        return Self(
            maximumCapacityPercentage: nominal ?? raw ?? legacy,
            cycleCount: gaugeValue(properties["CycleCount"]) ?? gaugeValue(batteryData["CycleCount"])
        )
    }

    // Capacity and design must come from the same representation of the gauge.
    private static func capacityPercentage(in data: [String: Any], maximumKey: String) -> Int? {
        guard let design = gaugeValue(data["DesignCapacity"]), design > 100,
              let maximum = gaugeValue(data[maximumKey]), maximum > 0,
              maximumKey != "MaxCapacity" || maximum > 100 else {
            return nil
        }
        let percentage = Double(maximum) / Double(design) * 100
        guard (1...150).contains(percentage) else { return nil }
        return Int(percentage.rounded())
    }

    private static func gaugeValue(_ property: Any?) -> Int? {
        guard let number = property as? NSNumber,
              CFGetTypeID(number) == CFNumberGetTypeID(),
              let integer = UInt16(exactly: number.doubleValue), integer < UInt16.max else {
            return nil
        }
        return Int(integer)
    }
}
