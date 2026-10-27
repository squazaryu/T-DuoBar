import XCTest
@testable import DuoBar

final class BluetoothStartupTests: XCTestCase {
    @MainActor
    func testBlockedBluetoothReadDoesNotBlockLaunchAndRefreshesCoalesce() async throws {
        let reader = BlockingBluetoothReader()
        let service = BluetoothService(readStatus: { reader.read() })
        var received: [BluetoothStatus] = []
        service.onStatusChange = { received.append($0) }
        let began = ContinuousClock.now
        service.start()
        XCTAssertLessThan(began.duration(to: .now), .milliseconds(100))
        for _ in 0..<50 where reader.count == 0 { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertEqual(reader.count, 1)
        for _ in 0..<20 { service.refresh() }
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(reader.count, 1, "A blocked read must not grow an unbounded queue")
        reader.release()
        for _ in 0..<100 where received.count < 2 { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(reader.count, 2, "Refresh requests coalesce into one follow-up")
        XCTAssertTrue(received.allSatisfy(\.isPoweredOn))
    }
}

private final class BlockingBluetoothReader: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var reads = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return reads }
    func read() -> BluetoothStatus {
        lock.lock(); reads += 1; let first = reads == 1; lock.unlock()
        if first { _ = gate.wait(timeout: .now() + 2) }
        return BluetoothStatus(isAvailable: true, isPoweredOn: true)
    }
    func release() { gate.signal() }
}
