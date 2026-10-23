import Network

struct NetworkPathCandidate {
    let name: String
    let type: NWInterface.InterfaceType
    let isUsed: Bool

    var isTunnel: Bool {
        // A leftover VPN interface is not evidence of an underlying connection.
        // Do not exclude all .other interfaces: bridges and cellular paths may
        // legitimately provide a connection that is neither Wi-Fi nor Ethernet.
        ["utun", "tun", "tap", "ipsec"].contains { prefix in
            guard name.hasPrefix(prefix) else { return false }
            let suffix = name.dropFirst(prefix.count)
            return !suffix.isEmpty && suffix.allSatisfy { $0.isASCII && $0.isNumber }
        }
    }
}

struct NetworkPathResolution: Equatable {
    let isConnected: Bool
    let transport: NetworkTransport
    let interfaceName: String?

    static func resolve(pathIsConnected: Bool, candidates: [NetworkPathCandidate],
                        hasWiFiInterface: Bool) -> Self {
        let offline = Self(isConnected: false, transport: hasWiFiInterface ? .wifi : .none, interfaceName: nil)
        guard pathIsConnected else { return offline }
        let usable = candidates.filter { $0.isUsed && $0.type != .loopback && !$0.isTunnel }
        let active = usable.first { $0.type == .wiredEthernet }
            ?? usable.first { $0.type == .wifi }
            ?? usable.first
        guard let active else { return offline }
        let transport: NetworkTransport
        switch active.type {
        case .wifi: transport = .wifi
        case .wiredEthernet: transport = .ethernet
        default: transport = .other
        }
        return Self(isConnected: true, transport: transport, interfaceName: active.name)
    }
}
