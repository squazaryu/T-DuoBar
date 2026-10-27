import SwiftUI

/// Scanning begins only after the user expands this list, never on pop-up open.
struct NearbyWiFiSection: View {
    @ObservedObject private var store: SystemStatusStore
    @ObservedObject private var controller: NearbyWiFiController
    private let onOpenSettings: () -> Void
    @State private var expanded = false
    @State private var passwordNetwork: NearbyWiFiNetwork?
    @State private var password = ""

    init(store: SystemStatusStore, initiallyExpanded: Bool = false, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.controller = store.nearbyWiFiController
        self.onOpenSettings = onOpenSettings
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                expanded.toggle()
                if !expanded { clearPassword(); controller.deactivate() }
            } label: {
                HStack {
                    Label(localized("Nearby Networks"), systemImage: "wifi")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .font(.system(size: 8, weight: .semibold))
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(localized(expanded ? "Expanded" : "Collapsed"))

            AnimatedDisclosureContent(isExpanded: expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    if controller.isWiFiPoweredOn == false {
                        Text(localized("Wi-Fi is Off")).foregroundStyle(.secondary)
                    } else {
                        if controller.isBusy {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text(localized(isJoining ? "Joining…" : "Scanning…")).foregroundStyle(.secondary)
                            }
                        }
                        if !controller.networks.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(controller.networks) { network in networkRow(network) }
                                }
                            }
                            .frame(height: min(CGFloat(controller.networks.count) * 30, 150))
                        } else if !controller.isBusy {
                            Text(localized("No nearby networks found. Check Location Services or open Wi-Fi Settings."))
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let network = passwordNetwork {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: network.ssid).fontWeight(.medium).lineLimit(1)
                            SecureField(localized("Wi-Fi password"), text: $password)
                                .textFieldStyle(.roundedBorder)
                                .disabled(controller.isBusy)
                                .onSubmit { join(network, password: password) }
                            HStack {
                                Button(localized("Cancel")) { clearPassword(); controller.clearTransientState() }
                                    .disabled(controller.isBusy)
                                Spacer()
                                Button(localized("Join")) { join(network, password: password) }
                                    .disabled(password.isEmpty || controller.isBusy)
                            }
                        }.padding(8).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if case let .failure(message) = controller.state {
                        Text(verbatim: message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Button(localized("Refresh")) { Task { await store.refreshNearbyWiFi() } }
                            .disabled(controller.isBusy || controller.isWiFiPoweredOn == false)
                        Spacer()
                        Button(localized("Wi-Fi Settings…"), action: onOpenSettings)
                    }.buttonStyle(.link)
                }
                .padding(.top, 8)
            }
        }
        .clipped()
        .modifier(SectionDisclosureAnimation(isExpanded: expanded))
        .task(id: expanded) {
            if expanded { await store.openNearbyWiFi() }
        }
        .onChange(of: controller.isVisible) { visible in
            if !visible { expanded = false; clearPassword() }
        }
        .onChange(of: controller.isWiFiPoweredOn) { enabled in
            if enabled == false { clearPassword() }
        }
        .onDisappear { clearPassword(); controller.deactivate() }
    }

    private var isJoining: Bool {
        if case .joining = controller.state { return true }
        return false
    }

    private func networkRow(_ network: NearbyWiFiNetwork) -> some View {
        Button {
            controller.clearTransientState()
            if !network.security.supportsDirectAssociation {
                clearPassword()
                onOpenSettings()
            } else if network.security.requiresPassword {
                clearPassword()
                passwordNetwork = network
            } else {
                clearPassword()
                join(network, password: nil)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "wifi", variableValue: network.signalSymbolVariableValue)
                    .frame(width: 16)
                Text(verbatim: network.ssid).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                if network.isCurrent { Image(systemName: "checkmark").foregroundStyle(.secondary) }
                if network.security != .open { Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 4).frame(height: 30).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(controller.isBusy || network.isCurrent)
        .accessibilityLabel(network.ssid)
        .accessibilityHint(localized(network.security.supportsDirectAssociation ? "Join Network" : "Open Wi-Fi Settings"))
    }

    private func clearPassword() { password = ""; passwordNetwork = nil }

    private func join(_ network: NearbyWiFiNetwork, password submittedPassword: String?) {
        guard !controller.isBusy else { return }
        password = ""
        Task {
            let joined = await store.joinNearbyWiFi(network, password: submittedPassword)
            if joined {
                clearPassword()
                await store.refreshNearbyWiFi()
            }
        }
    }
}
