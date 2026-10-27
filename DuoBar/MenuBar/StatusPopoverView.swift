import AppKit
import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @ObservedObject private var accessoryService: AccessoryBatteryService
    @AppStorage(PreferenceKeys.popoverLayout) private var layoutRaw = PopoverLayout.standard.rawValue
    @AppStorage(PreferenceKeys.language) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(PreferenceKeys.hideEmptyAccessories) private var hideEmptyAccessories = false
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.showNetwork) private var showNetwork = true
    @AppStorage(PreferenceKeys.showVPN) private var showVPN = true
    @AppStorage(PreferenceKeys.showVolume) private var showVolume = true
    @AppStorage(PreferenceKeys.showBattery) private var showBattery = true
    @AppStorage(PreferenceKeys.showAccessories) private var showAccessories = true
    @AppStorage(PreferenceKeys.showAudioOutput) private var showAudioOutput = true
    @AppStorage(PreferenceKeys.showMicrophone) private var showMicrophone = false
    @AppStorage(PreferenceKeys.showBatteryTime) private var showBatteryTime = true
    @AppStorage(PreferenceKeys.menuSectionOrder) private var sectionOrder = MenuSectionOrder.defaultValue
    @State private var contentHeight: CGFloat = 316
    private let onHeightChange: (CGFloat) -> Void
    private let onClose: () -> Void

    init(statusStore: SystemStatusStore, onHeightChange: @escaping (CGFloat) -> Void = { _ in }, onClose: @escaping () -> Void) {
        self.statusStore = statusStore
        self.accessoryService = statusStore.accessoryBatteryService
        self.onClose = onClose
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        ScrollView {
            content.background(GeometryReader { geometry in
                Color.clear.preference(key: PopoverContentHeightKey.self, value: geometry.size.height)
            })
        }
        .frame(width: 304, height: min(contentHeight, maximumHeight))
        // NSPopover and SwiftUI update their heights on different layout passes.
        // Fill the host and keep the scroll view at its top during that interval.
        .frame(maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(PopoverContentHeightKey.self) { height in
            guard height > 0 else { return }
            contentHeight = height
            onHeightChange(min(height, maximumHeight))
        }
    }

    private var maximumHeight: CGFloat { min(600, (NSScreen.main?.visibleFrame.height ?? 700) - 80) }

    var content: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    onClose()
                    AboutPanel.show()
                } label: {
                    Text(AppIdentity.name).font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.plain)
                .help(localized("About T-DuoBar"))
                .accessibilityLabel(localized("About T-DuoBar"))
                Spacer()
                DuoGlyphView(
                    status: statusStore.status,
                    metrics: DuoGlyphMetrics.standard.sized(20),
                    animationsEnabled: false,
                    batteryColorCodingEnabled: batteryColorCoding
                )
            }
            .padding(.horizontal, 2)

            if layout == .compact {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleSections.enumerated()), id: \.element.id) { index, section in
                            if index > 0 { compactDivider }
                            sectionView(section)
                        }
                    }
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
                    // The last boundary belongs to the section grid. Keeping it
                    // outside this stack adds the root's 8-point spacing to the
                    // apparent last-row height, regardless of which section is last.
                    compactDivider
                }
            } else {
                ForEach(visibleSections) { section in sectionView(section) }
                Divider()
            }

            StatusPopoverFooter(compact: layout == .compact, onQuit: { NSApp.terminate(nil) }) {
                settingsAction
            }
        }
        .padding(12)
        .frame(width: 304)
        .id(languageRaw + layout.rawValue)
        .environment(\.popoverLayout, layout)
        .environment(\.locale, (AppLanguage(rawValue: languageRaw) ?? .system).locale)
    }

    private var compactDivider: some View {
        Divider().padding(.leading, 35).padding(.trailing, 10)
    }

    private var layout: PopoverLayout { PopoverLayout.resolve(layoutRaw) }
    private var visibleSections: [MenuSection] { MenuSectionOrder.decode(sectionOrder).filter(isVisible) }

    private func isVisible(_ section: MenuSection) -> Bool {
        switch section {
        case .network: showNetwork
        case .vpn: showVPN
        case .volume: showVolume
        case .battery: showBattery
        case .accessories:
            showAccessories && AccessorySectionVisibility.showsSection(hideEmpty: hideEmptyAccessories,
                deviceCount: accessoryService.accessories.count, hasError: accessoryService.errorMessage != nil)
        case .audioOutput: showAudioOutput
        case .microphone: showMicrophone
        }
    }

    @ViewBuilder
    private func sectionView(_ section: MenuSection) -> some View {
        switch section {
        case .network:
            networkSection
        case .vpn:
            VPNSection(service: statusStore.vpnStatusService, onOpenSettings: openVPNSettings)
        case .volume:
            if layout == .compact {
                CompactVolumeSection(volume: statusStore.status.audio.volume,
                    hasOutputDevice: statusStore.status.audio.defaultOutput != nil,
                    playbackDeviceIdentifier: statusStore.status.audio.defaultOutput?.uid,
                    onSetVolume: statusStore.setVolume, onSetMuted: statusStore.setMuted,
                    onOpenSettings: openSoundSettings)
            } else {
                HStack(spacing: 0) {
                    volumeRow
                    SystemSettingsButton(title: localized("Sound Settings…"), action: openSoundSettings)
                        .padding(.trailing, 8)
                }
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
            }
        case .battery:
            batterySection
        case .accessories:
            AccessoryBatterySection(service: statusStore.accessoryBatteryService, onOpenSettings: openBluetoothSettings)
        case .audioOutput:
            AudioDevicesSection(title: "Audio Output", symbol: audioOutputSymbol,
                devices: statusStore.status.audio.selectableOutputs,
                selectedUID: statusStore.status.audio.defaultOutput?.uid, allowsFavorites: true,
                onSelect: statusStore.setDefaultOutput, onOpenSettings: openSoundSettings)
        case .microphone:
            AudioDevicesSection(title: "Microphone", symbol: "mic",
                devices: statusStore.status.audio.availableInputs,
                selectedUID: statusStore.status.audio.defaultInput?.uid,
                onSelect: statusStore.setDefaultInput, onOpenSettings: openSoundSettings)
        }
    }

    private var volumeRow: some View {
        VolumeStatusRow(volume: statusStore.status.audio.volume,
            hasOutputDevice: statusStore.status.audio.defaultOutput != nil,
            playbackDeviceIdentifier: statusStore.status.audio.defaultOutput?.uid,
            onSetVolume: statusStore.setVolume, onSetMuted: statusStore.setMuted, drawsBackground: false)
    }

    private var networkSection: some View {
        StatusDetailSection(settingsTitle: networkSettingsHint, onOpenSettings: openNetworkSettings) {
            StatusRow(symbol: networkSymbol, title: localized("Network"), detail: networkDetail,
                stateText: networkState, tint: .primary, drawsBackground: false, accessory: .disclosure)
        } content: {
            if !statusStore.status.network.isAvailable {
                Text(localized("No network interface is available. Check your connection in System Settings."))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let issue = WiFiNameAvailabilityIssue(network: statusStore.status.network) {
                Text(issue.message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                switch issue {
                case .needsLocationAccess:
                    Button(localized("Allow access…")) {
                        statusStore.requestWiFiSSIDAccess(trigger: .popoverOpened)
                    }.buttonStyle(.link)
                case .locationAccessDenied, .locationAccessRestricted:
                    Button(localized("Location Settings…"), action: openLocationSettings).buttonStyle(.link)
                case .notReported:
                    EmptyView()
                }
            }
            if let error = statusStore.wifiPowerControlError {
                Text(error).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let toggle = wifiPowerToggle {
                HStack { Text(localized("Wi-Fi power")); Spacer(); toggle }
            }
            if statusStore.status.network.transport == .wifi, statusStore.status.network.isConnected {
                StatusDetailLine(title: "Signal", value: statusStore.status.network.rssi.map { "\($0) dBm" })
                StatusDetailLine(title: "Band", value: statusStore.status.network.wifiBand)
                StatusDetailLine(title: "Channel", value: statusStore.status.network.wifiChannel.map(String.init))
            }
            if statusStore.status.network.isConnected {
                HStack {
                    StatusDetailLine(title: "IP address", value: statusStore.status.network.localIPAddress)
                    if let address = statusStore.status.network.localIPAddress {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(address, forType: .string)
                        } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).accessibilityLabel(localized("Copy IP address"))
                    }
                }
            }
            Divider()
            NearbyWiFiSection(store: statusStore) {
                _ = SystemSettingsOpener.open(.wifi)
                onClose()
            }
        }
    }

    private var batterySection: some View {
        let battery = statusStore.status.battery
        return StatusDetailSection(settingsTitle: localized("Open Battery Settings"), onOpenSettings: openBatterySettings) {
            BatteryStatusRow(battery: battery, showPercentage: showBatteryPercentage,
                showsDisclosure: true, showsRemainingTime: showBatteryTime,
                hasInternalBattery: statusStore.deviceContext.hasInternalBattery, drawsBackground: false)
        } content: {
            if battery.isAvailable {
                if layout == .compact {
                    Text(battery.powerStateDescription).foregroundStyle(.secondary)
                    if showBatteryTime, let time = battery.remainingTimeDescription {
                        Text(time).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                StatusDetailLine(title: "Power source", value: localized(battery.isPluggedIn ? "Power adapter connected" : "Using battery power"))
                if battery.isPluggedIn {
                    StatusDetailLine(title: "Adapter power", value: battery.adapterWatts.map { localized("%d W", $0) })
                    if battery.adapterWatts == nil {
                        Text(localized("macOS has not reported the adapter power.")).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if showBatteryTime, battery.remainingTimeMinutes == nil, !battery.isFullyCharged,
                   !battery.isPluggedIn || battery.isCharging {
                    Text(localized("macOS has not provided a time estimate yet. Check again after the power source or workload settles."))
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Text(localized("The charge limit is unavailable to T-DuoBar. Check charging options in Battery Settings."))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(localized(statusStore.deviceContext.hasInternalBattery
                    ? "Could not read the battery status. Check Battery Settings."
                    : "This Mac has no internal battery."))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var settingsAction: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsLabel
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
                onClose()
            })
        } else {
            Button(action: openSettingsFromApplicationMenu) {
                settingsLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsLabel: some View {
        StatusPopoverSettingsLabel(compact: layout == .compact)
    }

    private func openSettingsFromApplicationMenu() {
        SettingsWindowOpener.open()
        onClose()
    }

    private var networkSettingsHint: String {
        SystemSettingsOpener.pane(for: statusStore.status.network) == .network
            ? localized("Open Network Settings")
            : localized("Open Wi-Fi Settings")
    }

    private func openNetworkSettings() {
        _ = SystemSettingsOpener.open(SystemSettingsOpener.pane(for: statusStore.status.network))
        onClose()
    }

    private func openBatterySettings() {
        _ = SystemSettingsOpener.open(.battery)
        onClose()
    }

    private func openSoundSettings() {
        _ = SystemSettingsOpener.open(.sound)
        onClose()
    }

    private func openVPNSettings() {
        _ = SystemSettingsOpener.open(.vpn)
        onClose()
    }

    private func openBluetoothSettings() {
        _ = SystemSettingsOpener.open(.bluetooth)
        onClose()
    }

    private func openLocationSettings() {
        _ = SystemSettingsOpener.open(.locationServices)
        onClose()
    }

    private var networkSymbol: String {
        let network = statusStore.status.network
        guard network.isConnected else { return "network.slash" }
        switch network.transport {
        case .wifi: return network.usesPersonalHotspotSymbol ? "personalhotspot" : "wifi"
        case .ethernet: return EthernetGlyph.symbolName
        case .other: return "ellipsis.circle"
        case .none: return "network.slash"
        }
    }

    private var networkDetail: String {
        let network = statusStore.status.network
        if statusStore.wifiPowerControlError != nil {
            return localized("Unable to change Wi-Fi power")
        }
        guard network.isAvailable else { return localized("No network interface") }
        guard network.isConnected else {
            return network.isWiFiPoweredOn == false ? localized("Wi-Fi disabled") : localized("Not connected")
        }
        switch network.transport {
        case .wifi: return network.ssid ?? localized("Network name unavailable")
        case .ethernet: return network.interfaceName ?? localized("Wired connection")
        case .other: return network.interfaceName ?? localized("Active connection")
        case .none: return localized("Not connected")
        }
    }

    private var networkState: String {
        let network = statusStore.status.network
        guard network.isAvailable else { return localized("Unavailable") }
        if network.isWiFiPoweredOn == false, !network.isConnected { return localized("Off") }
        guard network.isConnected else { return localized("Offline") }
        switch network.transport {
        case .wifi: return localized(network.usesPersonalHotspotSymbol ? "Personal Hotspot" : "Wi-Fi")
        case .ethernet: return localized("Ethernet")
        case .other: return localized("Connected")
        case .none: return localized("Offline")
        }
    }

    private var wifiPowerToggle: AnyView? {
        guard let wifiPowerState = statusStore.status.network.isWiFiPoweredOn else { return nil }
        return AnyView(
            Toggle(localized("Wi-Fi power"), isOn: Binding(
                get: { wifiPowerState },
                set: { statusStore.setWiFiPower($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .accessibilityLabel(localized("Wi-Fi power"))
        )
    }

    private var audioOutputSymbol: String {
        guard let output = statusStore.status.audio.defaultOutput else { return "speaker.slash" }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? "airpodspro" : "headphones"
        }
        return "speaker.wave.2"
    }

    private var audioOutputDetail: String {
        statusStore.status.audio.defaultOutput?.name ?? localized("No output device")
    }

    private var audioOutputState: String {
        guard let output = statusStore.status.audio.defaultOutput else { return localized("Unavailable") }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? localized("AirPods") : localized("Bluetooth")
        }
        switch output.transport {
        case .builtIn: return localized("Built-in")
        case .airPlay: return localized("AirPlay")
        case .usb: return localized("USB")
        case .hdmi, .displayPort: return localized("Display")
        case .virtual: return localized("Virtual")
        case .bluetooth, .bluetoothLE: return localized("Bluetooth")
        case .other: return localized("Connected")
        }
    }
}

struct BatteryStatusRow: View {
    @Environment(\.popoverLayout) private var layout
    let battery: BatteryStatus
    let showPercentage: Bool
    var showsDisclosure = false
    var showsRemainingTime = true
    var hasInternalBattery: Bool? = nil
    var drawsBackground = true

    @ViewBuilder
    var body: some View {
        if layout == .compact {
            CompactStatusRow(symbol: symbol, title: localized("Battery"), value: compactValue)
        } else {
            standardBody
        }
    }

    var compactValue: String {
        CompactBatterySummary.value(battery: battery, showPercentage: showPercentage,
            showsRemainingTime: showsRemainingTime, fallback: detail)
    }

    private var standardBody: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                StatusRowHeader(title: localized("Battery"), value: trailingValue)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if showsRemainingTime, let time = battery.remainingTimeDescription {
                    Text(time)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                StatusRowAccessorySlot(symbol: "chevron.right")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: !showsRemainingTime || battery.remainingTimeDescription == nil ? 48 : 64)
        .background(.primary.opacity(drawsBackground ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    var trailingValue: String? {
        guard showPercentage, let percentage = battery.percentage else { return nil }
        return localized("%d%%", percentage)
    }

    var detail: String {
        guard battery.isAvailable else {
            return localized(hasInternalBattery == false ? "No internal battery" : "Battery data unavailable")
        }
        return battery.powerStateDescription
    }

    private var symbol: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        if battery.isFullyCharged { return "battery.100percent" }
        switch battery.percentage ?? 0 {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        default: return "battery.25percent"
        }
    }
}

#if DEBUG
private struct DebugStatusSimulatorView: View {
    let statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Label("Debug Simulator", systemImage: "hammer")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu("Simulate") {
                    Menu("Battery Level") {
                        ForEach(DebugBatteryLevel.allCases) { level in
                            Button(level.title) { statusStore.applyDebugBatteryLevel(level) }
                        }
                    }
                    Menu("Battery Power") {
                        ForEach(DebugPowerState.allCases) { powerState in
                            Button(powerState.rawValue) { statusStore.applyDebugPowerState(powerState) }
                        }
                    }
                    Menu("Low Power Mode") {
                        ForEach(DebugLowPowerMode.allCases) { lowPowerMode in
                            Button(lowPowerMode.rawValue) { statusStore.applyDebugLowPowerMode(lowPowerMode) }
                        }
                    }
                    Menu("Battery Color Coding") {
                        Button("Off") { batteryColorCoding = false }
                        Button("On") { batteryColorCoding = true }
                    }
                    Menu("Network") {
                        ForEach(DebugNetworkState.allCases) { networkState in
                            Button(networkState.rawValue) { statusStore.applyDebugNetworkState(networkState) }
                        }
                    }
                    Menu("Volume") {
                        ForEach(DebugVolumeState.allCases) { volumeState in
                            Button(volumeState.rawValue) { statusStore.applyDebugVolumeState(volumeState) }
                        }
                    }
                    Menu("Audio Connection") {
                        ForEach(DebugAudioDeviceState.allCases) { deviceState in
                            Button(deviceState.rawValue) { statusStore.applyDebugAudioDeviceState(deviceState) }
                        }
                    }
                    Divider()
                    Button("Restore Live Data") { statusStore.restoreLiveStatus() }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Divider()

            LabeledContent("Laptop Ring Mode", value: laptopRingModeLabel)
            LabeledContent("Charging session", value: chargingSessionLabel)
            LabeledContent("Adaptive telemetry lease", value: adaptiveRingMonitor.monitoringOwnerCount > 0 ? "Active" : "Inactive")
            LabeledContent("Adaptive monitor", value: adaptiveRingMonitor.isMonitoring ? "Running" : "Stopped")
            LabeledContent("Adaptive source", value: adaptiveRingMonitor.debugTestSource.rawValue)
            LabeledContent("Brightness", value: brightnessLabel)
            LabeledContent("Adaptive metric", value: adaptiveRingMonitor.state.diagnosticLabel)
            LabeledContent("Adaptive progress", value: adaptiveProgressLabel)
            LabeledContent("Final ring override", value: finalRingOverrideLabel)

        }
        .padding(.horizontal, 6)
        .frame(minHeight: 26)
    }

    private var laptopRingModeLabel: String {
        switch statusStore.laptopRingModeState.mode {
        case .battery: "Battery"
        case .adaptive: "Adaptive"
        }
    }

    private var chargingSessionLabel: String {
        guard let start = statusStore.laptopRingModeState.sessionStartPercentage,
              let target = statusStore.laptopRingModeState.targetPercentage
        else { return "None" }
        let waiting = statusStore.laptopRingModeState.isWaitingForFullChargeDelay ? " · waiting for full delay" : ""
        return "\(start)% → \(target)%\(waiting)"
    }

    private var brightnessLabel: String {
        guard let availability = adaptiveRingMonitor.brightnessSnapshot?.availability else { return "Sampling…" }
        switch availability {
        case .available(let value): return String(format: "%.0f%%", value * 100)
        case .unavailable: return "Unavailable"
        }
    }

    private var adaptiveProgressLabel: String {
        let target = AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress
        return String(format: "%.1f%%", target * 100)
    }

    private var finalRingOverrideLabel: String {
        guard statusStore.usesAdaptiveRing else { return "Battery Ring" }
        let target = AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress
        return String(format: "%.1f%%", target * 100)
    }
}
#endif

private struct PopoverContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
