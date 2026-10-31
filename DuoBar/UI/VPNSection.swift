import SwiftUI

struct VPNSection: View {
    @Environment(\.menuTypography) private var typography
    @Environment(\.popoverLayout) private var layout
    @ObservedObject var service: VPNStatusService
    let onOpenSettings: () -> Void
    var initiallyExpanded = false

    private var isInitialRead: Bool { service.isRefreshing && !service.status.isAvailable }

    var body: some View {
        StatusDetailSection(initiallyExpanded: initiallyExpanded,
            settingsTitle: localized("Open VPN Settings"), onOpenSettings: onOpenSettings) {
            if layout == .compact {
                CompactStatusRow(symbol: "lock.shield", title: localized("VPN"),
                    value: isInitialRead ? localized("Checking…")
                        : compactSummary,
                    tint: service.status.state == .connected ? .green : .primary)
            } else {
                standardHeader
            }
        } content: {
            details
        }
    }

    private var compactSummary: String {
        guard service.status.isAvailable, !service.status.connections.isEmpty else { return service.status.state.title }
        return service.status.summary + " · " + service.status.state.title
    }

    private var standardHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: "lock.shield")
                .font(.system(size: typography.size(13), weight: .semibold))
                .foregroundStyle(service.status.state == .connected ? Color.green : .primary)
                .frame(width: 28, height: 28)
                .background((service.status.state == .connected ? Color.green : .primary).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                StatusRowHeader(title: localized("VPN"), value: isInitialRead
                    ? localized("Checking…") : service.status.state.title)
                Text(isInitialRead ? localized("Reading VPN status…") : service.status.summary)
                    .font(.system(size: typography.size(10.5)))
                    .foregroundStyle(typography.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StatusRowAccessorySlot(symbol: "chevron.right")
        }
        .padding(.horizontal, 10)
        .frame(height: typography.readable ? 56 : 48)
    }

    @ViewBuilder
    private var details: some View {
        if isInitialRead {
            Text(localized("Reading VPN status…")).foregroundStyle(typography.secondary)
        } else if !service.status.isAvailable {
            Text(localized("macOS could not read VPN status."))
                .foregroundStyle(typography.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(localized("Try again")) {
                if service.isMonitoring { service.refresh() } else { service.start() }
            }
            .buttonStyle(.link)
            .disabled(service.isRefreshing)
        } else if service.status.connections.isEmpty {
            Text(localized("No macOS VPN profiles found"))
                .foregroundStyle(typography.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ForEach(service.status.connections) { connection in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(connection.displayName).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(connection.state.title).foregroundStyle(typography.secondary)
                    }
                    if let interfaceName = connection.interfaceName {
                        StatusDetailLine(title: "Interface", value: interfaceName)
                    }
                }
            }
        }
        Text(localized("Only VPN connections reported by macOS are shown."))
            .foregroundStyle(typography.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
