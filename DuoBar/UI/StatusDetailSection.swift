import SwiftUI

struct StatusDetailSection<Header: View, Content: View>: View {
    @Environment(\.popoverLayout) private var layout
    @State private var expanded = false
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content
    private let settingsTitle: String?
    private let onOpenSettings: (() -> Void)?

    init(initiallyExpanded: Bool = false, settingsTitle: String? = nil, onOpenSettings: (() -> Void)? = nil,
         @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.header = header()
        self.content = content()
        self.settingsTitle = settingsTitle
        self.onOpenSettings = onOpenSettings
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button { expanded.toggle() } label: {
                    header
                        .environment(\.statusSectionExpanded, expanded)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Plain buttons otherwise exclude transparent gaps from hit testing.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint(localized("Show details"))
                .accessibilityValue(expanded ? localized("Expanded") : localized("Collapsed"))
                if layout == .standard, let settingsTitle, let onOpenSettings {
                    SystemSettingsButton(title: settingsTitle, action: onOpenSettings)
                        .padding(.trailing, 8)
                }
            }
            AnimatedDisclosureContent(isExpanded: expanded) {
                VStack(alignment: .leading, spacing: 7) {
                    Divider()
                    content
                    if layout == .compact, let settingsTitle, let onOpenSettings {
                        Button(settingsTitle, action: onOpenSettings).buttonStyle(.link)
                    }
                }.font(.system(size: 10.5)).padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .modifier(SectionDisclosureAnimation(isExpanded: expanded))
        .background(.primary.opacity(layout == .compact ? 0 : 0.045), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct StatusDetailLine: View {
    let title: String
    let value: String?
    var body: some View {
        HStack {
            Text(localized(title)).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value ?? localized("Unavailable")).monospacedDigit()
                .textSelection(.enabled)
        }
    }
}

private struct StatusSectionExpandedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var statusSectionExpanded: Bool {
        get { self[StatusSectionExpandedKey.self] }
        set { self[StatusSectionExpandedKey.self] = newValue }
    }
}
