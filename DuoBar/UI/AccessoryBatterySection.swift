import SwiftUI

struct AccessoryBatterySection: View {
    @Environment(\.menuTypography) private var typography
    @Environment(\.popoverLayout) private var layout
    @ObservedObject var service: AccessoryBatteryService
    var onOpenSettings: (() -> Void)? = nil

    @ViewBuilder
    var body: some View {
        if layout == .compact {
            StatusDetailSection(settingsTitle: localized("Bluetooth Settings…"), onOpenSettings: onOpenSettings) {
                CompactStatusRow(symbol: "keyboard", title: localized("Accessories"), value: compactSummary,
                    fallbackValue: singleAccessory?.percentage.map { localized("%d%%", $0) })
            } content: {
                if service.accessories.isEmpty { emptyState }
                else { connectedAccessories }
            }
        } else {
            standardBody
        }
    }

    private var compactSummary: String {
        if service.isRefreshing && service.accessories.isEmpty { return localized("Reading accessories…") }
        if service.errorMessage != nil { return localized("Accessory battery data unavailable") }
        guard !service.accessories.isEmpty else { return localized("No devices") }
        if let item = singleAccessory {
            return item.name + " · " + (item.percentage.map { localized("%d%%", $0) } ?? "—")
        }
        return localized("Devices: %d", service.accessories.count)
    }

    private var singleAccessory: AccessoryBattery? {
        service.accessories.count == 1 ? service.accessories.first : nil
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if service.accessories.isEmpty {
                emptyState
            } else {
                connectedAccessories
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                if layout == .standard {
                    StatusRow(symbol: "keyboard", title: localized("Accessory batteries"),
                        detail: service.isRefreshing ? localized("Reading accessories…")
                            : localized(service.errorMessage == nil ? "No connected accessories" : "Accessory battery data unavailable"),
                        stateText: "", tint: .primary, drawsBackground: false)
                }
                if layout == .compact {
                    Text(compactSummary).font(.system(size: typography.size(10.5))).foregroundStyle(typography.secondary)
                }
                if layout == .standard, let onOpenSettings {
                    SystemSettingsButton(title: localized("Bluetooth Settings…"), action: onOpenSettings)
                        .padding(.trailing, 8)
                }
            }
            if service.errorMessage != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Could not read accessory data. Check the Bluetooth connection and try again."))
                        .font(.system(size: typography.size(10.5))).foregroundStyle(typography.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(localized("Try again")) { service.refresh(force: true) }
                        .buttonStyle(.link).controlSize(.small).disabled(service.isRefreshing)
                }
                .padding(.horizontal, 10).padding(.bottom, 10)
            }
        }
    }

    private var connectedAccessories: some View {
        VStack(alignment: .leading, spacing: 4) {
            if layout == .standard {
                HStack {
                    Text(localized("Accessory batteries"))
                        .font(.system(size: typography.size(11), weight: .semibold))
                        .foregroundStyle(typography.secondary)
                    Spacer(minLength: 2)
                    if let onOpenSettings {
                        SystemSettingsButton(title: localized("Bluetooth Settings…"), action: onOpenSettings)
                    }
                }
            }
            ForEach(service.accessories) { accessory in
                AccessoryBatteryRow(accessory: accessory)
            }
        }
        .padding(layout == .standard ? 10 : 0)
    }
}

private struct AccessoryBatteryRow: View {
    @Environment(\.menuTypography) private var typography
    let accessory: AccessoryBattery

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: accessory.symbol)
                .font(.system(size: typography.size(13), weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: typography.size(26), height: typography.size(26))
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(.system(size: typography.size(11.5), weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !componentSummary.isEmpty {
                    Text(componentSummary)
                        .font(.system(size: typography.size(9.5)))
                        .foregroundStyle(typography.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Text(percentageLabel ?? "—")
                    .font(.system(size: typography.size(11.5), weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(percentageLabel == nil ? typography.secondary : AnyShapeStyle(.primary))
                    .fixedSize()
                    .frame(minWidth: typography.size(32), alignment: .trailing)
                AccessoryBatteryGauge(percentage: accessory.percentage)
            }
            .fixedSize()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessory.name))
        .accessibilityValue(Text(accessibilityValue))
    }

    private var percentageLabel: String? { accessory.percentage.map { localized("%d%%", $0) } }

    private var componentSummary: String {
        [("left", "Left"), ("right", "Right"), ("case", "Case")].compactMap { key, title in
            accessory.levels[key].map { localized(title) + " " + localized("%d%%", $0) }
        }.joined(separator: " · ")
    }

    private var accessibilityValue: String {
        let charge = percentageLabel ?? localized("Battery reading unavailable")
        return componentSummary.isEmpty ? charge : charge + " · " + componentSummary
    }
}

private struct AccessoryBatteryGauge: View {
    @Environment(\.menuTypography) private var typography
    let percentage: Int?

    var body: some View {
        let level = percentage ?? 0
        let color: Color = level < 20 ? .red : .primary
        let width = typography.size(18)
        let height = typography.size(10)
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 2.5)
                .strokeBorder(color.opacity(0.6), lineWidth: 1)
                .frame(width: width, height: height)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: (width - 4) * CGFloat(level) / 100, height: height - 4)
                        .padding(.leading, 2)
                }
            Capsule().fill(color.opacity(0.6)).frame(width: 1.5, height: typography.size(4))
        }
        .opacity(percentage == nil ? 0 : 1)
        .accessibilityHidden(true)
    }
}
