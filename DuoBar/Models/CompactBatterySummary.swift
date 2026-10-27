import Foundation

enum CompactBatterySummary {
    /// The expanded section owns the full power-state explanation. Do not let
    /// that sentence squeeze the percentage into an ellipsis in the header.
    static func value(battery: BatteryStatus, showPercentage: Bool,
                      showsRemainingTime: Bool, fallback: String) -> String {
        guard battery.isAvailable else { return fallback }
        var values: [String] = []
        if showPercentage, let percentage = battery.percentage {
            values.append(localized("%d%%", percentage))
        }
        if showsRemainingTime, let minutes = battery.remainingTimeMinutes {
            let duration = minutes == 0 ? localized("Less than one minute")
                : minutes < 60 ? localized("%d min", minutes)
                : localized("%d h %d min", minutes / 60, minutes % 60)
            values.append("≈" + duration)
        }
        return values.isEmpty ? fallback : values.joined(separator: " · ")
    }
}
