import SwiftUI

struct NetworkDiagnosticsSection: View {
    @ObservedObject var service: NetworkDiagnosticsService
    let network: NetworkStatus

    private var connectionID: String { "\(network.transport)|\(network.isConnected)|\(network.interfaceName ?? "")|\(network.ssid ?? "")" }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Button(localized("Check connection"), action: service.check)
                    .buttonStyle(.link).disabled(service.isRunning || !network.isConnected)
                if service.isRunning { ProgressView().controlSize(.mini) }
            }
            Text(localized("Checks www.apple.com over HTTPS. DNS errors are reported separately. Runs only on request."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !network.isConnected {
                Text(localized("Connect to a network before checking.")).foregroundStyle(.secondary)
            }
            if let result = service.result {
                StatusDetailLine(title: "Name resolution", value: result.dns.title)
                StatusDetailLine(title: "HTTPS reachability", value: result.https.title)
                Text(result.message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: connectionID) { _ in service.cancel() }
        .onDisappear { service.cancel() }
    }
}
