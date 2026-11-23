import Combine
import Darwin
import Foundation

@MainActor
final class NetworkTrafficMonitor: ObservableObject {
    typealias ReadSample = @Sendable (String) async -> NetworkTrafficSample?

    @Published private(set) var rates: NetworkTrafficRates?

    private let readSample: ReadSample
    private var popoverVisible = false
    private var displayedInterface: String?
    private var samplingTask: Task<Void, Never>?

    init(readSample: @escaping ReadSample = { await NetworkTrafficInterface.readSample($0) }) {
        self.readSample = readSample
    }

    func setPopoverVisible(_ visible: Bool) {
        guard visible != popoverVisible else { return }
        popoverVisible = visible
        restartSampling()
    }

    func setDisplayedInterface(_ interfaceName: String?) {
        guard interfaceName != displayedInterface else { return }
        displayedInterface = interfaceName
        restartSampling()
    }

    private func restartSampling() {
        samplingTask?.cancel()
        samplingTask = nil
        if rates != nil { rates = nil }
        guard popoverVisible, let displayedInterface else { return }

        let readSample = readSample
        samplingTask = Task { [weak self] in
            var previousSample: NetworkTrafficSample?
            while !Task.isCancelled {
                let sample = await readSample(displayedInterface)
                // A read already enqueued on the worker can finish after a close
                // or an interface change. Its cancelled task never publishes it.
                guard !Task.isCancelled else { return }
                let newRates = previousSample.flatMap { sample?.rates(since: $0) }
                previousSample = sample
                if self?.rates != newRates {
                    self?.rates = newRates
                }

                do {
                    try await Task.sleep(for: .seconds(1), tolerance: .milliseconds(100))
                } catch {
                    return
                }
            }
        }
    }

    deinit { samplingTask?.cancel() }
}

private enum NetworkTrafficInterface {
    private static let queue = DispatchQueue(label: "com.mikeli.duobar.network-traffic", qos: .utility)

    static func readSample(_ interfaceName: String) async -> NetworkTrafficSample? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: loadSample(interfaceName))
            }
        }
    }

    private static func loadSample(_ interfaceName: String) -> NetworkTrafficSample? {
        guard let interfaceIndex = Int32(exactly: if_nametoindex(interfaceName)),
              interfaceIndex > 0 else { return nil }

        // IFMIB returns counters for just this interface in a 64-bit structure.
        var query = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, interfaceIndex, IFDATA_GENERAL]
        var result = ifmibdata()
        var size = MemoryLayout<ifmibdata>.size
        guard sysctl(&query, u_int(query.count), &result, &size, nil, 0) == 0,
              size == MemoryLayout<ifmibdata>.size,
              result.ifmd_flags & UInt32(IFF_UP) != 0 else { return nil }
        let nameMatches = withUnsafeBytes(of: result.ifmd_name) { buffer in
            buffer.prefix(while: { $0 != 0 }).elementsEqual(interfaceName.utf8)
        }
        guard nameMatches else { return nil }

        let stats = result.ifmd_data
        let lastChange = stats.ifi_lastchange
        return NetworkTrafficSample(
            interfaceIndex: interfaceIndex,
            interfaceChangeTime: Int64(lastChange.tv_sec) * 1_000_000 + Int64(lastChange.tv_usec),
            receivedBytes: stats.ifi_ibytes,
            sentBytes: stats.ifi_obytes,
            time: .now,
            awakeTime: .now
        )
    }
}
