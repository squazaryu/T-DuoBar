import SwiftUI

/// Animate user expansion only, without animating incoming telemetry updates.
struct SectionDisclosureAnimation: ViewModifier {
    static let duration = 0.18
    let isExpanded: Bool
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(Self.animation(enabled: animationsEnabled, reduceMotion: reduceMotion), value: isExpanded)
    }

    static func animation(enabled: Bool, reduceMotion: Bool) -> Animation? {
        enabled && !reduceMotion ? .easeInOut(duration: duration) : nil
    }
}
