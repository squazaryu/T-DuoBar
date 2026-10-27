import SwiftUI

/// A disclosure label only: its parent owns expansion, controls and actions.
struct CompactStatusRow: View {
    let symbol: String
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if symbol == EthernetGlyph.symbolName { EthernetGlyph(width: 16) }
                else { Image(systemName: symbol) }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint).frame(width: 17)
            .accessibilityHidden(true)
            Text(title).font(.system(size: 11.5, weight: .medium))
                .lineLimit(1).layoutPriority(1)
            Spacer(minLength: 6)
            Text(value).font(.system(size: 10.5)).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle).monospacedDigit()
            StatusRowAccessorySlot(symbol: "chevron.right")
        }
        .padding(.horizontal, 10).frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
