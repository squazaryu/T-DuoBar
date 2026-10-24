import SwiftUI

/// Keep the compact footer on the same icon/text grid as the disclosure rows.
struct StatusPopoverFooter<Settings: View>: View {
    let compact: Bool
    let onQuit: () -> Void
    @ViewBuilder let settings: Settings

    var body: some View {
        HStack(spacing: 8) {
            settings
            Spacer(minLength: 12)
            Button(action: onQuit) {
                Text(localized("Quit DuoBar"))
                    .lineLimit(1)
                    .frame(height: compact ? 34 : nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.system(size: 11.5, weight: .medium))
        .padding(.horizontal, compact ? 10 : 3)
        .frame(height: compact ? 34 : nil)
    }
}

struct StatusPopoverSettingsLabel: View {
    let compact: Bool

    @ViewBuilder
    var body: some View {
        if compact {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 17)
                    .accessibilityHidden(true)
                Text(localized("Settings"))
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .frame(height: 34)
            .contentShape(Rectangle())
        } else {
            Label(localized("Settings"), systemImage: "gearshape")
        }
    }
}
