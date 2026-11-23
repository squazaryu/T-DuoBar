import SwiftUI

struct DesktopIndicatorView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @ObservedObject private var priorityController: StatusPriorityController
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    @AppStorage(PreferenceKeys.language) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false

    init(statusStore: SystemStatusStore) {
        self.statusStore = statusStore
        priorityController = statusStore.priorityController
    }

    var body: some View {
        GeometryReader { geometry in
            let edge = min(geometry.size.width, geometry.size.height)
            let surface = RoundedRectangle(cornerRadius: edge * 0.24)
            let usesAdaptiveRing = statusStore.usesReleasedAdaptiveRing
            let ring = DuoPersistentRingPresentationResolver.resolve(
                mode: usesAdaptiveRing ? .adaptive : .battery,
                battery: statusStore.status.battery,
                adaptiveProgress: AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress,
                batteryColorCodingEnabled: batteryColorCoding
            )
            let ringColor = usesAdaptiveRing ? AdaptiveRingColorResolver.resolve(
                state: adaptiveRingMonitor.state,
                decision: adaptiveRingMonitor.performanceDecision,
                colorCodingEnabled: adaptiveRingColorCoding
            ).color : nil

            DuoGlyphView(
                status: statusStore.status,
                presentation: priorityController.presentation,
                metrics: .standard.sized(edge * 0.76),
                animationsEnabled: animationsEnabled,
                ringPresentation: ring,
                ringColorOverride: ringColor,
                batteryColorCodingEnabled: batteryColorCoding,
                showsBatteryPercentage: true
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(nsColor: .windowBackgroundColor), in: surface)
            .overlay { surface.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatusAccessibilitySummary.text(
            for: statusStore.status,
            language: AppLanguage(rawValue: languageRaw) ?? .system
        ))
    }
}
