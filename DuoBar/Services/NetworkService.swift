import AppKit
@preconcurrency import CoreLocation
@preconcurrency import CoreWLAN
import Foundation
@preconcurrency import Network

@MainActor
final class NetworkService: NSObject, @preconcurrency CLLocationManagerDelegate {
    var onStatusChange: ((NetworkStatus) -> Void)?

    private let client = CWWiFiClient.shared()
    private let wifiPowerCoordinator: WiFiPowerControlCoordinator
    private let locationManager = CLLocationManager()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mikeli.duobar.network-monitor", qos: .utility)
    private var latestPath: NWPath?
    private var detailRefreshTimer: Timer?
    private var applicationActivationObserver: NSObjectProtocol?
    #if DEBUG
    private var debugSSIDManualRefreshObserver: NSObjectProtocol?
    #endif
    private var lastStatus: NetworkStatus?
    private var isStarted = false
    private var ssidAccessCoordinator = SSIDAccessCoordinator()

    override init() {
        wifiPowerCoordinator = WiFiPowerControlCoordinator(
            controller: CoreWLANWiFiPowerController(interfaceProvider: { CWWiFiClient.shared().interface() })
        )
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        locationManager.delegate = self

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.latestPath = path
                self?.refresh(reason: .pathChange)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        applicationActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applicationDidBecomeActive() }
        }

        #if DEBUG
        debugSSIDManualRefreshObserver = NotificationCenter.default.addObserver(
            forName: .debugSSIDManualRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: .manual) }
        }
        #endif

        // NWPathMonitor supplies immediate connection and interface changes. This
        // low-frequency refresh is only for CoreWLAN details such as changing RSSI.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: .periodic) }
        }
        timer.tolerance = 1.5
        detailRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        refresh(reason: .startup)
    }

    func requestSSIDAccess(trigger: LocationRequestTrigger) {
        performSSIDAccessActions(
            ssidAccessCoordinator.requestAccess(
                authorization: SSIDAuthorizationState(locationManager.authorizationStatus),
                applicationIsActive: NSApp.isActive,
                trigger: trigger
            )
        )
    }

    func refresh() {
        refresh(reason: .manual)
    }

    private func refresh(reason: NetworkRefreshReason) {
        let path = latestPath ?? pathMonitor.currentPath
        let defaultWiFiInterface = client.interface()
        let connection = NetworkPathResolution.resolve(
            pathIsConnected: path.status == .satisfied,
            candidates: path.availableInterfaces.map {
                NetworkPathCandidate(name: $0.name, type: $0.type, isUsed: path.usesInterfaceType($0.type))
            },
            hasWiFiInterface: defaultWiFiInterface != nil
        )
        let isConnected = connection.isConnected
        let transport = connection.transport
        let wifiInterface = transport == .wifi && isConnected
            ? client.interface(withName: connection.interfaceName) ?? defaultWiFiInterface
            : defaultWiFiInterface
        let wifiPoweredOn = wifiInterface?.powerOn()

        var ssid: String?
        var rssi: Int?
        var rawSSID: String?
        if transport == .wifi, isConnected, let wifiInterface {
            rawSSID = wifiInterface.ssid()
            ssid = SSIDValue.normalized(rawSSID)
            let rawRSSI = wifiInterface.rssiValue()
            rssi = rawRSSI == 0 ? nil : rawRSSI
        }

        let status = NetworkStatus(
            isAvailable: wifiInterface != nil || !path.availableInterfaces.isEmpty,
            isConnected: isConnected,
            transport: transport,
            interfaceName: connection.interfaceName,
            isWiFiPoweredOn: wifiPoweredOn,
            ssid: ssid,
            rssi: rssi,
            wifiChannel: transport == .wifi && isConnected ? wifiInterface?.wlanChannel()?.channelNumber : nil,
            wifiBand: transport == .wifi && isConnected ? Self.bandName(wifiInterface?.wlanChannel()) : nil,
            localIPAddress: isConnected ? LocalNetworkAddress.ipv4(interface: connection.interfaceName) : nil,
            ssidAuthorization: SSIDAuthorizationState(locationManager.authorizationStatus),
            isExpensive: path.isExpensive
        )
        publish(status)

        #if DEBUG
        SSIDDiagnosticCenter.shared.update(
            SSIDHardwareDiagnostic(
                authorization: SSIDAuthorizationState(locationManager.authorizationStatus),
                applicationIsActive: NSApp.isActive,
                interfaceName: wifiInterface?.interfaceName,
                isWiFiPoweredOn: wifiPoweredOn,
                rawSSID: rawSSID,
                networkStatusSSID: status.ssid,
                pathDescription: isConnected ? pathDescription(path, transport: transport) : "Unsatisfied",
                rssi: rssi,
                refreshReason: reason,
                locationRequestAttempted: ssidAccessCoordinator.hasAttemptedAuthorizationRequest,
                locationRequestIssuedWhileActive: ssidAccessCoordinator.wasAuthorizationRequestIssuedWhileActive,
                lastLocationRequestTrigger: ssidAccessCoordinator.lastRequestTrigger
            )
        )
        #endif
    }

    private static func bandName(_ channel: CWChannel?) -> String? {
        guard let channel else { return nil }
        switch channel.channelBand {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        default: return nil
        }
    }

    func setWiFiPower(_ enabled: Bool) -> WiFiPowerControlResult {
        let result = wifiPowerCoordinator.setPower(enabled)
        // Re-read the existing sources immediately. NWPathMonitor will still
        // publish any later routing/reconnection transition independently.
        refresh(reason: .wifiPowerChange)
        return result
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        performSSIDAccessActions(
            ssidAccessCoordinator.authorizationDidChange(
                to: SSIDAuthorizationState(manager.authorizationStatus)
            )
        )
    }

    private func applicationDidBecomeActive() {
        performSSIDAccessActions(
            ssidAccessCoordinator.applicationDidBecomeActive(
                authorization: SSIDAuthorizationState(locationManager.authorizationStatus)
            )
        )
        // A Developer ID/TCC transition can leave the first CoreWLAN read
        // cached as nil. Always re-read on activation so a newly granted
        // Location authorization replaces that stale unavailable value.
        refresh(reason: .manual)
    }

    private func performSSIDAccessActions(_ actions: [SSIDAccessAction]) {
        for action in actions {
            switch action {
            case .requestAuthorization:
                locationManager.requestWhenInUseAuthorization()
                refresh(reason: .authorizationChange)
            case .refresh:
                refresh(reason: .authorizationChange)
            }
        }
    }

    private func publish(_ status: NetworkStatus) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatusChange?(status)
    }

    #if DEBUG
    private func pathDescription(_ path: NWPath, transport: NetworkTransport) -> String {
        guard path.status == .satisfied else { return "Unsatisfied" }
        switch transport {
        case .wifi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .other: return "Other"
        case .none: return "Unsatisfied"
        }
    }
    #endif

    deinit {
        detailRefreshTimer?.invalidate()
        pathMonitor.cancel()
        if let applicationActivationObserver {
            NotificationCenter.default.removeObserver(applicationActivationObserver)
        }
        #if DEBUG
        if let debugSSIDManualRefreshObserver {
            NotificationCenter.default.removeObserver(debugSSIDManualRefreshObserver)
        }
        #endif
    }
}
