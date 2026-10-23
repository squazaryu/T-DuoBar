import CoreGraphics

/// Placement relative to the visible ink, rather than the SF Symbol's frame.
/// Values are normalized to the center font size and do not depend on live
/// hardware readings, backing scale, or battery-percentage visibility.
enum DuoCenterOpticalAlignment {
    static func offset(for state: DuoCenterState, size: CGFloat) -> CGSize {
        let normalized: CGSize
        switch state {
        case .wifi:
            // The broad top arcs put most of the ink above the frame midpoint.
            normalized = CGSize(width: 0, height: 0.08)
        case .airPodsPro:
            normalized = CGSize(width: 0, height: 0.05)
        case .airPods:
            normalized = CGSize(width: 0, height: 0.11)
        case .airPodsMax, .performanceThermal:
            normalized = CGSize(width: state == .performanceThermal ? -0.045 : 0, height: -0.04)
        case .headphones:
            normalized = CGSize(width: 0, height: -0.03)
        case .performanceMemory:
            normalized = CGSize(width: 0, height: -0.02)
        case .personalHotspot, .ethernet, .offline, .other, .unavailable, .audioDevice, .performanceCPU:
            normalized = .zero
        }
        return CGSize(width: normalized.width * size, height: normalized.height * size)
    }
}
