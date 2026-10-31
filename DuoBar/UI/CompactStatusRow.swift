import SwiftUI

/// A disclosure label only: its parent owns expansion, controls and actions.
struct CompactStatusRow: View {
    @Environment(\.menuTypography) private var typography
    let symbol: String
    let title: String
    let value: String
    var tint: Color = .primary
    var fallbackValue: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if symbol == EthernetGlyph.symbolName { EthernetGlyph(width: 16) }
                else { Image(systemName: symbol) }
            }
            .font(.system(size: typography.size(12), weight: .medium))
            .foregroundStyle(tint).frame(width: 17)
            .accessibilityHidden(true)
            Text(title).font(.system(size: typography.size(11.5), weight: .medium))
                .lineLimit(1).layoutPriority(1)
            Spacer(minLength: 6)
            Group {
                if let fallbackValue {
                    ViewThatFits(in: .horizontal) {
                        Text(value).fixedSize(horizontal: true, vertical: false)
                        Text(fallbackValue)
                    }
                    .accessibilityLabel(value)
                } else {
                    Text(value).truncationMode(.middle)
                }
            }
            .font(.system(size: typography.size(10.5))).foregroundStyle(typography.secondary)
            .lineLimit(1).monospacedDigit()
            StatusRowAccessorySlot(symbol: "chevron.right")
        }
        .padding(.horizontal, 10).frame(height: typography.compactHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
