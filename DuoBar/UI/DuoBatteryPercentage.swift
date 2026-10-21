import AppKit
import SwiftUI

/// Keeps missing readings and adaptive (CPU/memory) rings free of battery labels.
struct DuoBatteryPercentage: Equatable {
    let value: Int
    let showsBolt: Bool

    static func resolve(enabled: Bool, battery: BatteryStatus,
                        ringMode: DuoPersistentRingMode, colorCodingEnabled: Bool = false) -> Self? {
        guard enabled, ringMode == .battery, battery.isAvailable,
              let percentage = battery.percentage, (0...100).contains(percentage) else { return nil }
        return Self(value: battery.isFullyCharged ? 100 : percentage,
                    showsBolt: (battery.isPluggedIn || battery.isCharging) && !colorCodingEnabled)
    }

    var topGapDegrees: Double {
        let metrics = DuoGlyphMetrics.standard.sized(DuoGlyphMetrics.canvasSize)
        return DuoBatteryPercentageTypography(percentage: self, metrics: metrics,
            displayScale: 2).gapDegrees(metrics: metrics)
    }
}

struct DuoBatteryPercentageLabel: View {
    let percentage: DuoBatteryPercentage
    let metrics: DuoGlyphMetrics
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let type = DuoBatteryPercentageTypography(percentage: percentage, metrics: metrics, displayScale: displayScale)
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            let left = type.snap((metrics.overallSize - type.width) / 2, origin: origin.x)
            let textTop = type.snap(type.capTop - (type.font.ascender - type.font.capHeight), origin: origin.y)
            ZStack(alignment: .topLeading) {
                Text(verbatim: String(percentage.value))
                    .font(Font(type.font))
                    .fixedSize()
                    .frame(width: type.digitWidth, height: type.textHeight, alignment: .topLeading)
                    .position(x: left + type.digitWidth / 2, y: textTop + type.textHeight / 2)
                if percentage.showsBolt {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: type.boltSize, weight: .bold))
                        .fixedSize()
                        .frame(width: type.boltWidth, height: type.capHeight)
                        .position(x: left + type.digitWidth + type.spacing + type.boltWidth / 2,
                                  y: type.capTop + type.capHeight / 2)
                }
            }
        }
        .frame(width: metrics.overallSize, height: metrics.overallSize)
        .foregroundStyle(.primary)
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
        if remainingLength > leftLength + 1e-9 {
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
