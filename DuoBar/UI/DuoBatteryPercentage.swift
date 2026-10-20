import SwiftUI

/// Keeps missing readings and adaptive (CPU/memory) rings free of battery labels.
struct DuoBatteryPercentage: Equatable {
    let value: Int
    let showsPower: Bool

    static func resolve(enabled: Bool, battery: BatteryStatus,
                        ringMode: DuoPersistentRingMode) -> Self? {
        guard enabled, ringMode == .battery, battery.isAvailable,
              let percentage = battery.percentage, (0...100).contains(percentage) else { return nil }
        return Self(value: battery.isFullyCharged ? 100 : percentage,
                    showsPower: battery.isPluggedIn || battery.isCharging)
    }

    var topGapDegrees: Double {
        if value == 100 { return showsPower ? 144 : 116 }
        return showsPower ? 116 : 96
    }
}

struct DuoBatteryPercentageLabel: View {
    let percentage: DuoBatteryPercentage
    let metrics: DuoGlyphMetrics

    var body: some View {
        let scale = metrics.ringDiameter / DuoGlyphMetrics.standard.ringDiameter
        HStack(alignment: .firstTextBaseline, spacing: 0.5 * scale) {
            Text(verbatim: String(percentage.value))
                .font(.system(size: (percentage.value == 100 ? 11 : 12) * scale,
                              weight: .bold, design: .rounded))
                .monospacedDigit()
            if percentage.showsPower {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 6 * scale, weight: .bold))
            }
        }
        .fixedSize()
        .foregroundStyle(.primary)
        .offset(y: metrics.ringYOffset - metrics.ringDiameter * 0.38)
        .transaction { $0.animation = nil }
    }
}

/// Progress is measured along the two visible arcs, excluding the number gap.
/// Thus 50% always fills one side, even when 100 needs a wider label.
struct DuoPercentageArcShape: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let topGapDegrees: Double
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var segments: [ClosedRange<Double>] {
        let midpoint = (startDegrees + endDegrees) / 2
        let gap = min(max(topGapDegrees, 0), endDegrees - startDegrees)
        let leftEnd = midpoint - gap / 2
        let rightStart = midpoint + gap / 2
        let remainingLength = (endDegrees - startDegrees - gap) * Double(min(max(progress, 0), 1))
        guard remainingLength > 0 else { return [] }
        let leftLength = leftEnd - startDegrees
        var ranges = [startDegrees...min(leftEnd, startDegrees + remainingLength)]
        if remainingLength > leftLength {
            ranges.append(rightStart...min(endDegrees, rightStart + remainingLength - leftLength))
        }
        return ranges
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for segment in segments {
            let radius = min(rect.width, rect.height) / 2
            // Explicit subpaths avoid joining the two arcs across the digits.
            for index in 0...72 {
                let angle = (segment.lowerBound + (segment.upperBound - segment.lowerBound)
                    * Double(index) / 72) * .pi / 180
                let point = CGPoint(x: rect.midX + CGFloat(cos(angle)) * radius,
                                    y: rect.midY + CGFloat(sin(angle)) * radius)
                if index == 0 { path.move(to: point) }
                else { path.addLine(to: point) }
            }
        }
        return path
    }
}
