import Combine
import XCTest
@testable import DuoBar

final class NetworkTrafficTests: XCTestCase {
    func testRatesUseElapsedTimeAndHandleCountersLargerThan32Bits() {
        let timeline = TrafficTimeline()
        let baseline = timeline.sample(receive: 9_000_000_000, send: 8_000_000_000)
        let next = timeline.sample(receive: 9_003_000_000, send: 8_000_000_750, after: .milliseconds(1500))

        XCTAssertEqual(
            next.rates(since: baseline),
            NetworkTrafficRates(receiveBytesPerSecond: 2_000_000, sendBytesPerSecond: 500)
        )
    }

    func testCounterWrapIsAcceptedAndResetIsRejected() {
        let timeline = TrafficTimeline()
        let nearWrap = timeline.sample(receive: .max - 95, send: .max - 999)
        let wrapped = timeline.sample(receive: 32, send: 24, after: .seconds(1))
        XCTAssertEqual(
            wrapped.rates(since: nearWrap),
            NetworkTrafficRates(receiveBytesPerSecond: 128, sendBytesPerSecond: 1024)
        )

        let beforeReset = timeline.sample(receive: 9_000_000_000, send: 1_000)
        XCTAssertNil(wrapped.rates(since: beforeReset))
    }

    func testInvalidIntervalsSleepAndInterfaceChangeRequireNewBaseline() {
        let timeline = TrafficTimeline()
        let baseline = timeline.sample(receive: 1000, send: 1000)
        for invalid in [
            timeline.sample(receive: 2000, send: 2000),
            timeline.sample(receive: 2000, send: 2000, after: .milliseconds(200)),
            timeline.sample(receive: 2000, send: 2000, after: .seconds(4)),
            timeline.sample(receive: 2000, send: 2000, after: .seconds(2), awakeAfter: .seconds(1)),
            timeline.sample(receive: 2000, send: 2000, after: .seconds(1), index: 2),
            timeline.sample(receive: 2000, send: 2000, after: .seconds(1), changeTime: 1),
        ] {
            XCTAssertNil(invalid.rates(since: baseline))
        }
    }

    @MainActor
    func testSamplingRequiresVisibilityAndInterfaceAndDiscardsLateRead() async throws {
        let timeline = TrafficTimeline()
        let reader = TrafficReader()
        let monitor = NetworkTrafficMonitor { await reader.read($0) }
        var delivered: [NetworkTrafficRates] = []
        let subscription = monitor.$rates.compactMap { $0 }.sink { delivered.append($0) }
        defer {
            subscription.cancel()
            monitor.setPopoverVisible(false)
            Task { await reader.finish() }
        }

        monitor.setDisplayedInterface("en0")
        try await Task.sleep(for: .milliseconds(20))
        let hiddenRequests = await reader.count(for: "en0")
        XCTAssertEqual(hiddenRequests, 0)

        monitor.setPopoverVisible(true)
        try await waitUntil { await reader.count(for: "en0") == 1 }
        await reader.deliver(timeline.sample(receive: 1000, send: 1000), to: "en0")
        try await waitUntil { await reader.count(for: "en0") == 2 }

        monitor.setDisplayedInterface("en1")
        try await waitUntil { await reader.count(for: "en1") == 1 }
        await reader.deliver(timeline.sample(receive: 7000, send: 5000, after: .seconds(1)), to: "en0")
        await reader.deliver(timeline.sample(receive: 100, send: 100, index: 2), to: "en1")
        try await waitUntil { await reader.count(for: "en1") == 2 }
        XCTAssertNil(monitor.rates)

        await reader.deliver(timeline.sample(receive: 1124, send: 400, after: .seconds(1), index: 2), to: "en1")
        try await waitUntil { monitor.rates != nil }
        XCTAssertEqual(delivered, [NetworkTrafficRates(receiveBytesPerSecond: 1024, sendBytesPerSecond: 300)])

        monitor.setPopoverVisible(false)
        XCTAssertNil(monitor.rates)
        monitor.setPopoverVisible(true)
        try await waitUntil { await reader.count(for: "en1") == 3 }
        monitor.setDisplayedInterface(nil)
        await reader.deliver(timeline.sample(receive: 3000, send: 3000, after: .seconds(2), index: 2), to: "en1")
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(monitor.rates)
        XCTAssertEqual(delivered.count, 1)
    }

    @MainActor
    private func waitUntil(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw TrafficTestError.timedOut
    }
}

private enum TrafficTestError: Error { case timedOut }

private struct TrafficTimeline {
    let start = ContinuousClock.now
    let awakeStart = SuspendingClock.now

    func sample(receive: UInt64, send: UInt64, after elapsed: Duration = .zero,
                awakeAfter: Duration? = nil, index: Int32 = 1, changeTime: Int64 = 0) -> NetworkTrafficSample {
        NetworkTrafficSample(
            interfaceIndex: index,
            interfaceChangeTime: changeTime,
            receivedBytes: receive,
            sentBytes: send,
            time: start.advanced(by: elapsed),
            awakeTime: awakeStart.advanced(by: awakeAfter ?? elapsed)
        )
    }
}

private actor TrafficReader {
    private var requests: [String: Int] = [:]
    private var pending: [String: CheckedContinuation<NetworkTrafficSample?, Never>] = [:]
    private var finished = false

    func read(_ name: String) async -> NetworkTrafficSample? {
        guard !finished else { return nil }
        requests[name, default: 0] += 1
        return await withCheckedContinuation { pending[name] = $0 }
    }

    func count(for name: String) -> Int { requests[name, default: 0] }

    func deliver(_ sample: NetworkTrafficSample, to name: String) {
        pending.removeValue(forKey: name)?.resume(returning: sample)
    }

    func finish() {
        finished = true
        for continuation in pending.values { continuation.resume(returning: nil) }
        pending.removeAll()
    }
}
