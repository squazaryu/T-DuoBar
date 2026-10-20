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
        // Reserve room for the widest reading (100) at every charge level.
        // A fixed gap also prevents the arc ends jumping as the digits change.
        showsPower ? 156 : 144
    }
}

struct DuoBatteryPercentageLabel: View {
    let percentage: DuoBatteryPercentage
    let metrics: DuoGlyphMetrics

    var body: some View {
        let scale = metrics.ringDiameter / DuoGlyphMetrics.standard.ringDiameter
        HStack(alignment: .center, spacing: 1 * scale) {
            Text(verbatim: String(percentage.value))
                .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if percentage.showsPower {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 6 * scale, weight: .bold))
            }
        }
        .fixedSize()
        .foregroundStyle(.primary)
        .offset(y: metrics.ringYOffset - metrics.ringDiameter * 0.40)
        .transaction { $0.animation = nil }
    }
}

/// Progress is measured along the two visible arcs, excluding the number gap.
/// Thus 50% always fills one side, including the wider gap used with a power bolt.
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
