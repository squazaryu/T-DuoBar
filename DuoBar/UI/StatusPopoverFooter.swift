import SwiftUI

/// A quiet utility bar, visually lighter than the status sections above it.
struct StatusPopoverFooter<Settings: View>: View {
    let compact: Bool
    let onQuit: () -> Void
    @ViewBuilder let settings: Settings

    var body: some View {
        HStack(spacing: 8) {
            settings
            Spacer(minLength: 12)
            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(localized("Quit T-DuoBar"))
            .accessibilityLabel(localized("Quit T-DuoBar"))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, compact ? 10 : 3)
        .frame(height: 26)
    }
}

struct StatusPopoverSettingsLabel: View {
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .font(.system(size: 11))
                .frame(width: 17)
                .accessibilityHidden(true)
            Text(localized("Settings"))
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .frame(height: 26)
        .contentShape(Rectangle())
    }
}
