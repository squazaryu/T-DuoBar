import XCTest
@testable import DuoBar

final class NearbyWiFiTests: XCTestCase {
    func testCurrentNetworkWinsDeduplicationAndSortingIsDeterministic() {
        let candidates = [candidate("weak", ssid: "Home", rssi: -80, current: true),
                          candidate("strong", ssid: "Home", rssi: -30),
                          candidate("z", ssid: "Zulu", rssi: -50), candidate("a", ssid: "Alpha", rssi: -50),
                          candidate("blank", ssid: "  ", rssi: -20)]
        XCTAssertEqual(NearbyWiFiListBuilder.makeNetworks(from: candidates).map(\.id), ["weak", "a", "z"])
        XCTAssertEqual(NearbyWiFiListBuilder.makeNetworks(from: candidates.reversed()).map(\.id), ["weak", "a", "z"])
    }

    func testDifferentSecurityTypesStaySeparate() {
        let list = NearbyWiFiListBuilder.makeNetworks(from: [candidate("open", ssid: "Home", security: .open),
                                                            candidate("secured", ssid: "Home", security: .personal)])
        XCTAssertEqual(list.count, 2)
        XCTAssertFalse(NearbyWiFiSecurity.enterprise.supportsDirectAssociation)
        XCTAssertFalse(NearbyWiFiSecurity.unsupported.supportsDirectAssociation)
    }

    @MainActor
    func testOpeningAppOrRefreshingHiddenListDoesNotScan() async {
        let provider = WiFiProviderStub()
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.refresh()
        await controller.scanIfNeeded()
        let count = await provider.scanCount
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testRetainedViewCannotStartRequestsAfterAppKitMenuCloses() async {
        let provider = WiFiProviderStub()
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        controller.setMenuVisible(false)
        await controller.activate()
        await controller.refresh()
        let count = await provider.scanCount
        XCTAssertEqual(count, 0)
        XCTAssertFalse(controller.isVisible)
    }

    @MainActor
    func testEmptyScanResultsAreCachedUntilExplicitRefresh() async {
        let provider = WiFiProviderStub()
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        await controller.activate()
        var count = await provider.scanCount
        XCTAssertEqual(count, 1)
        await controller.refresh()
        count = await provider.scanCount
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testAuthorizationChangeInvalidatesCacheWithoutScanningClosedMenu() async {
        let provider = WiFiProviderStub()
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        controller.deactivate()
        controller.invalidateScanCache()
        var count = await provider.scanCount
        XCTAssertEqual(count, 1)
        await controller.activate()
        count = await provider.scanCount
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testStoreAndMenuShutdownDoNotLeaveListActive() async {
        let provider = WiFiProviderStub()
        let store = SystemStatusStore(startServices: false, nearbyWiFiProvider: provider)
        let controller = MenuBarController(statusStore: store)
        var count = await provider.scanCount
        XCTAssertEqual(count, 0)
        store.nearbyWiFiController.setMenuVisible(true)
        await store.nearbyWiFiController.activate()
        XCTAssertTrue(store.nearbyWiFiController.isVisible)
        controller.invalidate()
        XCTAssertFalse(store.nearbyWiFiController.isVisible)
        await store.openNearbyWiFi()
        await store.refreshNearbyWiFi()
        count = await provider.scanCount
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testLateScanCannotRepopulateClosedMenu() async {
        let provider = WiFiProviderStub(candidates: [candidate("late")], suspended: true)
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        let task = Task { await controller.activate() }
        await provider.waitForScan()
        controller.deactivate()
        await provider.resumeScan()
        await task.value
        XCTAssertTrue(controller.networks.isEmpty)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.isBusy)
    }

    @MainActor
    func testRepeatedReopeningCoalescesPendingScans() async {
        let provider = WiFiProviderStub(candidates: [candidate("fresh")], suspended: true)
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        let task = Task { await controller.activate() }
        await provider.waitForScan()
        for _ in 0..<10 { controller.deactivate(); await controller.activate() }
        var count = await provider.scanCount
        XCTAssertEqual(count, 1)
        await provider.resumeScan()
        await task.value
        for _ in 0..<100 where controller.networks.isEmpty { await Task.yield() }
        count = await provider.scanCount
        XCTAssertEqual(count, 2)
        XCTAssertEqual(controller.networks.first?.id, "fresh")
    }

    @MainActor
    func testTurningWiFiOffRejectsPendingScanResults() async {
        let provider = WiFiProviderStub(candidates: [candidate("late")], suspended: true)
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        let task = Task { await controller.activate() }
        await provider.waitForScan()
        controller.networkChanged(wifiPoweredOn: false)
        await provider.resumeScan()
        await task.value
        XCTAssertTrue(controller.networks.isEmpty)
        XCTAssertEqual(controller.isWiFiPoweredOn, false)
    }

    @MainActor
    func testReenablingWiFiInvalidatesClosedListCacheWithoutBackgroundScan() async {
        let provider = WiFiProviderStub()
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        controller.networkChanged(wifiPoweredOn: false)
        controller.deactivate()
        controller.networkChanged(wifiPoweredOn: true)
        var count = await provider.scanCount
        XCTAssertEqual(count, 1)
        await controller.activate()
        count = await provider.scanCount
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testLateJoinCannotPublishSuccessAfterMenuCloses() async throws {
        let provider = WiFiProviderStub(candidates: [candidate("open", security: .open)], suspendedJoin: true)
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        let network = try XCTUnwrap(controller.networks.first)
        let join = Task { await controller.join(network, password: nil) }
        await provider.waitForJoin()
        let duplicate = await controller.join(network, password: nil)
        XCTAssertFalse(duplicate)
        controller.deactivate()
        await provider.resumeJoin()
        let accepted = await join.value
        XCTAssertFalse(accepted)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.isBusy)
    }

    @MainActor
    func testJoinRequiresCurrentScanResultAndValidPassword() async throws {
        let provider = WiFiProviderStub(candidates: [candidate("home", security: .personal),
                                                   candidate("enterprise", security: .enterprise)])
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        let network = try XCTUnwrap(controller.networks.first { $0.id == "home" })
        for password in ["", String(repeating: "a", count: 257), "invalid\0password"] {
            let joined = await controller.join(network, password: password)
            XCTAssertFalse(joined)
        }
        let foreign = NearbyWiFiNetwork(id: "foreign", ssid: "Foreign", rssi: -40, security: .open, isCurrent: false)
        let unknownJoined = await controller.join(foreign, password: nil)
        XCTAssertFalse(unknownJoined)
        let enterprise = try XCTUnwrap(controller.networks.first { $0.id == "enterprise" })
        let enterpriseJoined = await controller.join(enterprise, password: nil)
        XCTAssertFalse(enterpriseJoined)
        var joins = await provider.joinCount
        XCTAssertEqual(joins, 0)
        let joined = await controller.join(network, password: "test-passphrase")
        XCTAssertTrue(joined)
        joins = await provider.joinCount
        XCTAssertEqual(joins, 1)
        let selectedID = await provider.lastJoinedID
        XCTAssertEqual(selectedID, "home")
    }

    @MainActor
    func testOpenNetworkIgnoresExtraneousPasswordAndClosedListCannotJoin() async throws {
        let provider = WiFiProviderStub(candidates: [candidate("open", security: .open)])
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        let network = try XCTUnwrap(controller.networks.first)
        let joined = await controller.join(network, password: "not-needed")
        XCTAssertTrue(joined)
        let receivedPassword = await provider.receivedPassword
        XCTAssertFalse(receivedPassword)
        controller.deactivate()
        let closedJoin = await controller.join(network, password: nil)
        XCTAssertFalse(closedJoin)
    }

    @MainActor
    func testProviderErrorsDoNotExposeUnderlyingErrorDetails() async {
        let provider = WiFiProviderStub(fails: true)
        let controller = NearbyWiFiController(provider: provider, menuIsVisible: true)
        await controller.activate()
        XCTAssertEqual(controller.state, .failure(message: localized("Unable to Scan")))
    }

    private func candidate(_ id: String, ssid: String = "Demo network", rssi: Int = -50,
                           security: NearbyWiFiSecurity = .personal, current: Bool = false) -> NearbyWiFiScanCandidate {
        NearbyWiFiScanCandidate(id: id, ssid: ssid, bssid: nil, rssi: rssi, channelNumber: 6,
                                security: security, isCurrent: current)
    }
}

private actor WiFiProviderStub: NearbyWiFiProviding {
    private let candidates: [NearbyWiFiScanCandidate]
    private var suspended: Bool
    private let fails: Bool
    private let suspendedJoin: Bool
    private var joinContinuation: CheckedContinuation<Void, Never>?
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var scanCount = 0
    private(set) var joinCount = 0
    private(set) var lastJoinedID: String?
    private(set) var receivedPassword = false

    init(candidates: [NearbyWiFiScanCandidate] = [], suspended: Bool = false, fails: Bool = false,
         suspendedJoin: Bool = false) {
        self.candidates = candidates; self.suspended = suspended; self.fails = fails
        self.suspendedJoin = suspendedJoin
    }
    func scan() async throws -> NearbyWiFiScanResult {
        scanCount += 1
        if suspended { await withCheckedContinuation { continuation = $0 } }
        if fails { throw NSError(domain: "private-provider-details", code: 1) }
        return NearbyWiFiScanResult(isWiFiPoweredOn: true, networks: candidates)
    }
    func associate(networkID: String, password: String?) async throws {
        joinCount += 1; lastJoinedID = networkID; receivedPassword = password != nil
        if suspendedJoin { await withCheckedContinuation { joinContinuation = $0 } }
    }
    func waitForScan() async {
        for _ in 0..<1000 {
            if continuation != nil { return }
            await Task.yield()
        }
    }
    func resumeScan() { suspended = false; continuation?.resume(); continuation = nil }
    func waitForJoin() async {
        for _ in 0..<1000 {
            if joinContinuation != nil { return }
            await Task.yield()
        }
    }
    func resumeJoin() { joinContinuation?.resume(); joinContinuation = nil }
}
