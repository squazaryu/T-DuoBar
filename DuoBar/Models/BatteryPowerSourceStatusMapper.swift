import Foundation
import IOKit.ps

/// Adapted from upstream DuoBar v1.3.2, preserving T-DuoBar's time/adapter data.
enum BatteryPowerSourceStatusMapper {
    static func internalBattery(in descriptions: [[String: Any]]) -> [String: Any]? {
        descriptions.first { $0["Type"] as? String == kIOPSInternalBatteryType }
    }

    static func status(dictionary: [String: Any], adapterWatts: Int?, lowPowerModeEnabled: Bool) -> BatteryStatus {
        guard dictionary["Type"] as? String == kIOPSInternalBatteryType else { return .unavailable }
        let percentage: Int?
        if let current = dictionary[kIOPSCurrentCapacityKey] as? Int,
           let maximum = dictionary[kIOPSMaxCapacityKey] as? Int, current >= 0, maximum > 0 {
            let fraction = min(Double(current) / Double(maximum), 1)
            percentage = Int((fraction * 100).rounded())
        } else {
            percentage = nil
        }
        let pluggedIn = dictionary[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        return BatteryStatus(
            percentage: percentage,
            isCharging: dictionary[kIOPSIsChargingKey] as? Bool ?? false,
            isPluggedIn: pluggedIn,
            // Rounded capacity must not invent an authoritative full-charge state.
            isFullyCharged: dictionary[kIOPSIsChargedKey] as? Bool == true,
            isAvailable: true,
            isLowPowerModeEnabled: lowPowerModeEnabled,
            adapterWatts: pluggedIn ? adapterWatts.flatMap { (1...1000).contains($0) ? $0 : nil } : nil,
            timeToEmptyMinutes: dictionary[kIOPSTimeToEmptyKey] as? Int,
            timeToFullChargeMinutes: dictionary[kIOPSTimeToFullChargeKey] as? Int
        )
    }
}
