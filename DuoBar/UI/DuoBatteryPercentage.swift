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

    // Measure the monospaced rounded font once. Only the digit count changes
    // the width; battery readings reuse the cached advance without layout work.
    private static let digitAdvance: CGFloat = {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 11) } ?? font
        return ("0" as NSString).size(withAttributes: [.font: rounded]).width
    }()

    var topGapDegrees: Double {
        let width = CGFloat(String(value).count) * Self.digitAdvance + (showsBolt ? 5 : 0)
        let radius = DuoGlyphMetrics.standard.ringPathDiameter / 2
        let fraction = min(1, (width / 2 + (showsBolt ? 3 : 2)) / radius)
        let angle = 2 * asin(Double(fraction)) * 180 / .pi
        // Very wide labels clear the arc vertically instead of removing the
        // entire upper half. Pixel tests cover every reading and bolt state.
        return max(72, min(showsBolt ? 156 : 144, angle))
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
            if percentage.showsBolt {
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
