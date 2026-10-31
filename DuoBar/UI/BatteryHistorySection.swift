import Charts
import SwiftUI

struct BatteryHistorySection: View {
    @Environment(\.locale) private var locale
    @ObservedObject var history: BatteryHistoryStore
    @Environment(\.menuTypography) private var typography

    var body: some View {
        let now = Date()
        let points = BatteryHistory.points(history.samples, now: now)
        VStack(alignment: .leading, spacing: 7) {
            Text(localized("Battery history · 6 hours")).fontWeight(.medium)
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(x: .value(localized("Time"), point.sample.date), y: .value(localized("Charge"), point.sample.percentage),
                        series: .value("Session", point.segment))
                        .foregroundStyle(point.sample.pluggedIn ? Color.green : Color.accentColor)
                }
                .chartYScale(domain: 0...100)
                .chartXScale(domain: now.addingTimeInterval(-6 * 3600)...now)
                .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 2)) { _ in AxisValueLabel(format: .dateTime.hour().locale(locale)) } }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let percentage = value.as(Int.self) { Text(localized("%d%%", percentage)) }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 100)
                .accessibilityLabel(localized("Battery history · 6 hours"))
                .accessibilityValue(history.samples.last.map { localized("%d%%", $0.percentage) } ?? "—")
            } else {
                Text(localized("History appears as battery readings are collected."))
                    .foregroundStyle(typography.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let consumed = BatteryHistory.consumedLastHour(history.samples, now: now) {
                Text(localized("Used in the last hour: %d%%", consumed)).monospacedDigit()
            }
            Text(localized("Stored locally for 24 hours. Gaps and charging sessions are shown separately."))
                .font(.system(size: typography.size(9.5))).foregroundStyle(typography.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
