// Wi-Fi discovery models adapted from Mikeli7666/DuoBar v1.3.2 (MIT).
import Combine
import Foundation

enum NearbyWiFiSecurity: String, CaseIterable, Sendable {
    case open
    case personal
    case enterprise
    case unsupported

    var requiresPassword: Bool { self == .personal }

    var supportsDirectAssociation: Bool {
        self == .open || self == .personal
    }
}

struct NearbyWiFiScanCandidate: Equatable, Sendable {
    let id: String
    let ssid: String
    let bssid: String?
    let rssi: Int
    let channelNumber: Int?
    let security: NearbyWiFiSecurity
    let isCurrent: Bool
}

struct NearbyWiFiNetwork: Identifiable, Equatable, Sendable {
    let id: String
    let ssid: String
    let rssi: Int
    let security: NearbyWiFiSecurity
    let isCurrent: Bool

    var signalLevel: WiFiSignalLevel {
        if rssi >= -67 { return .strong }
        if rssi >= -75 { return .medium }
        return .weak
    }

    var signalSymbolName: String {
        switch signalLevel {
        case .strong: "wifi"
        case .medium: "wifi"
        case .weak: "wifi"
        case .disconnected, .disabled, .unavailable: "wifi"
        }
    }

    var signalSymbolVariableValue: Double {
        signalLevel.symbolVariableValue ?? 0.5
    }
}

enum NearbyWiFiListBuilder {
    static func makeNetworks(from candidates: [NearbyWiFiScanCandidate]) -> [NearbyWiFiNetwork] {
        var preferredByIdentity: [String: NearbyWiFiScanCandidate] = [:]

        for candidate in candidates {
            guard let ssid = SSIDValue.normalized(candidate.ssid) else { continue }
            let normalized = NearbyWiFiScanCandidate(
                id: candidate.id,
                ssid: ssid,
                bssid: candidate.bssid,
                rssi: candidate.rssi,
                channelNumber: candidate.channelNumber,
                security: candidate.security,
                isCurrent: candidate.isCurrent
            )
            let identity = "\(ssid)|\(candidate.security.rawValue)"

            if let existing = preferredByIdentity[identity] {
                if shouldPrefer(normalized, over: existing) {
                    preferredByIdentity[identity] = normalized
                }
            } else {
                preferredByIdentity[identity] = normalized
            }
        }

        return preferredByIdentity.values
            .map {
                NearbyWiFiNetwork(
                    id: $0.id,
                    ssid: $0.ssid,
                    rssi: $0.rssi,
                    security: $0.security,
                    isCurrent: $0.isCurrent
                )
            }
            .sorted(by: sortBefore)
    }

    private static func shouldPrefer(
        _ candidate: NearbyWiFiScanCandidate,
        over existing: NearbyWiFiScanCandidate
    ) -> Bool {
        if candidate.isCurrent != existing.isCurrent { return candidate.isCurrent }
        if candidate.rssi != existing.rssi { return candidate.rssi > existing.rssi }
        return candidate.id.localizedStandardCompare(existing.id) == .orderedAscending
    }

    private static func sortBefore(_ lhs: NearbyWiFiNetwork, _ rhs: NearbyWiFiNetwork) -> Bool {
        if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
        if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
        let nameOrder = lhs.ssid.localizedCaseInsensitiveCompare(rhs.ssid)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }
}

struct NearbyWiFiScanResult: Equatable, Sendable {
    let isWiFiPoweredOn: Bool
    let networks: [NearbyWiFiScanCandidate]
}

protocol NearbyWiFiProviding: Sendable {
    func scan() async throws -> NearbyWiFiScanResult
    func associate(networkID: String, password: String?) async throws
}

enum NearbyWiFiState: Equatable, Sendable {
    case idle
    case scanning
    case joining(networkID: String)
    case success(networkID: String)
    case failure(message: String)
}

@MainActor
final class NearbyWiFiController: ObservableObject {
    @Published private(set) var networks: [NearbyWiFiNetwork] = []
    @Published private(set) var state: NearbyWiFiState = .idle
    @Published private(set) var isWiFiPoweredOn: Bool?
    @Published private(set) var isVisible = false
    private(set) var isMenuVisible: Bool
    private let provider: any NearbyWiFiProviding
    private let cacheDuration: TimeInterval
    private let now: () -> Date
    private var lastSuccessfulScanDate: Date?
    private var requestGeneration: UInt = 0
    private var requestInFlight = false
    private var refreshIsPending = false

    init(provider: any NearbyWiFiProviding, menuIsVisible: Bool = false,
         cacheDuration: TimeInterval = 15, now: @escaping () -> Date = Date.init) {
        isMenuVisible = menuIsVisible
        self.provider = provider
        self.cacheDuration = cacheDuration
        self.now = now
    }

    var isBusy: Bool { requestInFlight }

    func setMenuVisible(_ visible: Bool) {
        isMenuVisible = visible
        if !visible { deactivate() }
    }

    func activate() async {
        guard isMenuVisible, !Task.isCancelled else { return }
        isVisible = true
        await scanIfNeeded()
    }

    func deactivate() {
        isVisible = false
        requestGeneration &+= 1
        refreshIsPending = false
        state = .idle
    }

    func networkChanged(wifiPoweredOn: Bool?) {
        let poweredOnAgain = isWiFiPoweredOn == false && wifiPoweredOn == true
        isWiFiPoweredOn = wifiPoweredOn
        if poweredOnAgain { invalidateScanCache() }
        if wifiPoweredOn == false {
            requestGeneration &+= 1
            refreshIsPending = false
            lastSuccessfulScanDate = nil
            networks = []
            state = .idle
        }
    }

    func invalidateScanCache() {
        lastSuccessfulScanDate = nil
        guard isVisible else { return }
        Task { [weak self] in await self?.refresh() }
    }

    func scanIfNeeded() async {
        if let lastSuccessfulScanDate {
            let age = now().timeIntervalSince(lastSuccessfulScanDate)
            if age >= 0 && age < cacheDuration { return }
        }
        await scan()
    }

    func refresh() async { await scan() }

    private func scan() async {
        guard isMenuVisible, isVisible, !Task.isCancelled else { return }
        guard !requestInFlight else {
            // Closing/reopening or repeated refreshes can queue only one scan.
            refreshIsPending = true
            state = .scanning
            return
        }
        requestInFlight = true
        requestGeneration &+= 1
        let generation = requestGeneration
        state = .scanning
        do {
            let result = try await provider.scan()
            if isVisible && generation == requestGeneration && !Task.isCancelled {
                isWiFiPoweredOn = result.isWiFiPoweredOn
                networks = result.isWiFiPoweredOn ? NearbyWiFiListBuilder.makeNetworks(from: result.networks) : []
                lastSuccessfulScanDate = now()
                state = .idle
            }
        } catch {
            if isVisible && generation == requestGeneration && !Task.isCancelled {
                state = .failure(message: Self.userFacingMessage(for: error))
            }
        }
        finishRequest()
    }

    @discardableResult
    func join(_ network: NearbyWiFiNetwork, password: String?) async -> Bool {
        guard isMenuVisible, isVisible, !isBusy, !Task.isCancelled else { return false }
        // Accept only a still-visible result from our own scan.
        guard let selected = networks.first(where: { $0.id == network.id }), selected == network else { return false }
        guard !selected.isCurrent else { return true }
        guard selected.security.supportsDirectAssociation else { return false }
        if selected.security.requiresPassword {
            guard let password, !password.isEmpty, password.utf8.count <= 256, !password.contains("\0") else {
                state = .failure(message: localized("Enter a valid Wi-Fi password."))
                return false
            }
        }
        requestInFlight = true
        requestGeneration &+= 1
        let generation = requestGeneration
        state = .joining(networkID: selected.id)
        do {
            try await provider.associate(networkID: selected.id, password: selected.security.requiresPassword ? password : nil)
            let accepted = isVisible && generation == requestGeneration && !Task.isCancelled
            if accepted {
                state = .success(networkID: selected.id)
                lastSuccessfulScanDate = nil
            }
            finishRequest()
            return accepted
        } catch {
            if isVisible && generation == requestGeneration && !Task.isCancelled {
                state = .failure(message: localized("Unable to Join"))
            }
            finishRequest()
            return false
        }
    }

    func clearTransientState() {
        if !isBusy { state = .idle }
    }

    private func finishRequest() {
        requestInFlight = false
        if isMenuVisible && isVisible && refreshIsPending {
            refreshIsPending = false
            Task { [weak self] in await self?.scan() }
        } else {
            switch state {
            case .scanning, .joining: state = .idle
            default: break
            }
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        switch error as? NearbyWiFiProviderError {
        case .wifiOff: return localized("Wi-Fi is Off")
        case .interfaceUnavailable: return localized("Wi-Fi unavailable")
        case .networkUnavailable, .associationUnsupported: return localized("Open Wi-Fi Settings")
        case .scanFailed, .none: return localized("Unable to Scan")
        }
    }
}

enum NearbyWiFiProviderError: Error, Equatable, Sendable {
    case wifiOff
    case interfaceUnavailable
    case networkUnavailable
    case associationUnsupported
    case scanFailed
}
