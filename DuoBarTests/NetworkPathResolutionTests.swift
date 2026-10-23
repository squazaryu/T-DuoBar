import Network
import XCTest
@testable import DuoBar

final class NetworkPathResolutionTests: XCTestCase {
    func testVPNOnlyPathIsOfflineEvenWhenMacOSReportsSatisfied() {
        for name in ["utun0", "utun17", "tun1", "tap2", "ipsec0"] {
            let actual = resolve([candidate(name, .other)])
            XCTAssertFalse(actual.isConnected, name)
            XCTAssertEqual(actual.transport, .wifi)
            XCTAssertNil(actual.interfaceName)
            XCTAssertEqual(center(for: actual), .offline)
        }
    }

    func testWiFiRemovalAndReturnWhileVPNTunnelRemains() {
        let tunnel = candidate("utun17", .other)
        let wifi = candidate("en0", .wifi)
        let connected = resolve([tunnel, wifi])
        XCTAssertEqual(connected.transport, .wifi)
        XCTAssertEqual(connected.interfaceName, "en0")
        XCTAssertEqual(center(for: connected), .wifi(.strong))
        let offline = resolve([tunnel, candidate("en0", .wifi, used: false)])
        XCTAssertFalse(offline.isConnected)
        XCTAssertEqual(center(for: offline), .offline)
        XCTAssertEqual(resolve([tunnel, wifi]), connected)
    }

    func testRoutedEthernetKeepsPriorityOverWiFiAndTunnel() {
        let actual = resolve([candidate("utun4", .other), candidate("en0", .wifi), candidate("en5", .wiredEthernet)])
        XCTAssertTrue(actual.isConnected)
        XCTAssertEqual(actual.transport, .ethernet)
        XCTAssertEqual(actual.interfaceName, "en5")
        XCTAssertEqual(center(for: actual), .ethernet)
    }

    func testDisconnectedPathCannotBeRevivedByAvailableInterfaces() {
        let actual = NetworkPathResolution.resolve(pathIsConnected: false,
            candidates: [candidate("en0", .wifi), candidate("en5", .wiredEthernet)], hasWiFiInterface: true)
        XCTAssertFalse(actual.isConnected)
        XCTAssertEqual(center(for: actual), .offline)
    }

    func testLoopbackAndUnusedInterfacesCannotClaimAConnection() {
        for candidates in [[candidate("lo0", .loopback)], [], [candidate("en5", .wiredEthernet, used: false)]] {
            let actual = resolve(candidates)
            XCTAssertFalse(actual.isConnected)
            XCTAssertEqual(center(for: actual), .offline)
        }
        let desktop = NetworkPathResolution.resolve(pathIsConnected: true,
            candidates: [candidate("utun0", .other)], hasWiFiInterface: false)
        XCTAssertFalse(desktop.isConnected)
        XCTAssertEqual(desktop.transport, .none)
    }

    func testRealUnclassifiedConnectionIsNotMistakenForOffline() {
        for candidate in [candidate("bridge0", .other), candidate("pdp_ip0", .cellular), candidate("en7", .other)] {
            let actual = resolve([candidate])
            XCTAssertTrue(actual.isConnected)
            XCTAssertEqual(actual.transport, .other)
            XCTAssertEqual(center(for: actual), .other)
        }
    }

    private func candidate(_ name: String, _ type: NWInterface.InterfaceType, used: Bool = true) -> NetworkPathCandidate {
        NetworkPathCandidate(name: name, type: type, isUsed: used)
    }

    private func resolve(_ candidates: [NetworkPathCandidate]) -> NetworkPathResolution {
        NetworkPathResolution.resolve(pathIsConnected: true, candidates: candidates, hasWiFiInterface: true)
    }

    private func center(for connection: NetworkPathResolution) -> DuoCenterState {
        var status = SystemStatus.unavailable
        status.network = NetworkStatus(isAvailable: true, isConnected: connection.isConnected,
            transport: connection.transport, interfaceName: connection.interfaceName,
            isWiFiPoweredOn: true, ssid: nil, rssi: -42)
        return DuoGlyphState(status: status).centerState
    }
}
