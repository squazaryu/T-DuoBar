import SwiftUI

struct NetworkTrafficDetail: View {
    @Environment(\.menuTypography) private var typography
    @Environment(\.statusSectionExpanded) private var expanded
    @ObservedObject var monitor: NetworkTrafficMonitor
    let interfaceName: String?

    private var displayedInterface: String? { expanded ? interfaceName : nil }

    var body: some View {
        HStack {
            Text(localized("Current traffic"))
                .foregroundStyle(typography.secondary)
            Spacer(minLength: 6)
            rate(monitor.rates?.receiveBytesPerSecond, symbol: "arrow.down", label: "Receive rate")
            rate(monitor.rates?.sendBytesPerSecond, symbol: "arrow.up", label: "Send rate")
        }
        .onAppear { monitor.setDisplayedInterface(displayedInterface) }
        .onChange(of: displayedInterface) { monitor.setDisplayedInterface($0) }
        .onDisappear { monitor.setDisplayedInterface(nil) }
    }

    private func rate(_ bytesPerSecond: Double?, symbol: String, label: String) -> some View {
        let amount = bytesPerSecond.map { rate in
            Int64(rate.rounded()).formatted(
                .byteCount(style: .decimal, spellsOutZero: false).locale(AppLocalization.language.locale)
            )
        }
        return HStack(spacing: 3) {
            Image(systemName: symbol)
                .foregroundStyle(typography.secondary)
            Text(amount.map { localized("%@/s", $0) } ?? "—")
                .monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(localized(label)))
        .accessibilityValue(Text(amount.map { localized("%@ per second", $0) } ?? localized("Unavailable")))
    }
}
