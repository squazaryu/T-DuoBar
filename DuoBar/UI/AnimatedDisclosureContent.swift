import SwiftUI

/// NSHostingView reports an implicit SwiftUI animation's final intrinsic size
/// immediately. Step the revealed height only while a disclosure is moving so
/// NSPopover and the glass panel receive the same intermediate sizes as SwiftUI.
struct AnimatedDisclosureContent<Content: View>: View {
    let isExpanded: Bool
    @ViewBuilder let content: Content
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var naturalHeight: CGFloat = 0
    @State private var revealedHeight: CGFloat = 0
    @State private var openingPending = false
    @State private var lastExpanded: Bool
    @State private var motion: Task<Void, Never>?

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
        _lastExpanded = State(initialValue: isExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded || revealedHeight > 0 {
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: DisclosureContentHeight.self, value: geometry.size.height)
                    })
            }
        }
        .frame(height: revealedHeight, alignment: .top)
        .clipped()
        .opacity(naturalHeight > 0 ? min(revealedHeight / naturalHeight, 1) : 0)
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(!isExpanded)
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
        .onPreferenceChange(DisclosureContentHeight.self) { height in
            guard height > 0, abs(height - naturalHeight) > 0.5 else { return }
            naturalHeight = height
            if isExpanded {
                resize(to: height, animated: !lastExpanded || openingPending || motion != nil)
                openingPending = false
            }
        }
        .onChange(of: isExpanded) { expanded in
            openingPending = expanded && naturalHeight == 0
            if !openingPending { resize(to: expanded ? naturalHeight : 0, animated: true) }
            lastExpanded = expanded
        }
        .onChange(of: animationsEnabled) { _ in finishMotion() }
        .onChange(of: reduceMotion) { _ in finishMotion() }
        .onDisappear {
            motion?.cancel()
            motion = nil
            revealedHeight = isExpanded ? naturalHeight : 0
            openingPending = false
        }
    }

    private func finishMotion() {
        motion?.cancel()
        motion = nil
        revealedHeight = isExpanded ? naturalHeight : 0
    }

    private func resize(to target: CGFloat, animated: Bool) {
        motion?.cancel()
        motion = nil
        guard animated, animationsEnabled, !reduceMotion, abs(target - revealedHeight) > 0.5 else {
            revealedHeight = target
            return
        }
        let start = revealedHeight
        motion = Task { @MainActor in
            let clock = ContinuousClock()
            let began = clock.now
            while !Task.isCancelled {
                let elapsed = began.duration(to: clock.now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                let progress = min(seconds / SectionDisclosureAnimation.duration, 1)
                let eased = progress * progress * (3 - 2 * progress)
                revealedHeight = start + (target - start) * eased
                if progress >= 1 { motion = nil; return }
                do { try await Task.sleep(for: .milliseconds(16)) }
                catch { return }
            }
        }
    }
}

private struct DisclosureContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
