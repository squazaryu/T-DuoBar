import SwiftUI

struct StatusRow: View {
    enum Accessory {
        case none
        case disclosure
        case menu
    }

    @Environment(\.popoverLayout) private var layout
    let symbol: String
    let title: String
    let detail: String
    let stateText: String
    let tint: Color
    let drawsBackground: Bool
    var accessory: Accessory = .none
    let trailing: AnyView?
    var onActivate: (() -> Void)?
    var activationHint: String?

    init(
        symbol: String,
        title: String,
        detail: String,
        stateText: String,
        tint: Color,
        drawsBackground: Bool = true,
        accessory: Accessory = .none,
        trailing: AnyView? = nil,
        onActivate: (() -> Void)? = nil,
        activationHint: String? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.stateText = stateText
        self.tint = tint
        self.drawsBackground = drawsBackground
        self.accessory = accessory
        self.trailing = trailing
        self.onActivate = onActivate
        self.activationHint = activationHint
    }

    @ViewBuilder
    var body: some View {
        if layout == .compact {
            CompactStatusRow(symbol: symbol, title: title, value: detail, tint: tint)
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        HStack(spacing: 8) {
            activationContent
            if let trailing {
                trailing
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(.primary.opacity(drawsBackground ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var activationContent: some View {
        if let onActivate {
            Group {
                if let activationHint {
                    Button(action: onActivate) {
                        labelContent
                    }
                    .accessibilityHint(activationHint)
                } else {
                    Button(action: onActivate) {
                        labelContent
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            labelContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var labelContent: some View {
        HStack(spacing: 11) {
            Group {
                if symbol == EthernetGlyph.symbolName {
                    EthernetGlyph(width: 18)
                } else {
                    Image(systemName: symbol)
                }
            }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)

            if trailing == nil {
                Text(stateText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(0)
            }

            if let accessorySymbol {
                StatusRowAccessorySlot(symbol: accessorySymbol)
            }
        }
        .contentShape(Rectangle())
    }

    private var accessorySymbol: String? {
        switch accessory {
        case .none: nil
        case .disclosure: "chevron.right"
        case .menu: "chevron.up.chevron.down"
        }
    }
}

struct StatusRowHeader: View {
    let title: String
    let value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            if let value {
                Text(value)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Align disclosure indicators independently of their intrinsic symbol widths.
struct StatusRowAccessorySlot: View {
    @Environment(\.statusSectionExpanded) private var isExpanded
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .rotationEffect(.degrees(symbol == "chevron.right" && isExpanded ? 90 : 0))
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 12, height: 16)
            .accessibilityHidden(true)
    }
}
