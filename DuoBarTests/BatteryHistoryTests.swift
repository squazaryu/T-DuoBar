import XCTest
@testable import DuoBar

@MainActor
final class BatteryHistoryTests: XCTestCase {
    func testSamplingIsBoundedAndPersistsAcrossLaunches() throws {
        let name = "BatteryHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let history = BatteryHistoryStore(defaults: defaults, now: { clock })
        history.record(status(80))
        for _ in 0..<30 { history.record(status(79)) }
        XCTAssertEqual(history.samples.count, 1)
        clock.addTimeInterval(30)
        history.record(status(79, plugged: true))
        XCTAssertEqual(history.samples.count, 2, "Power changes retain their boundary")
        for minute in 1...1600 {
            clock.addTimeInterval(60)
            history.record(status(79 - minute % 40))
        }
        history.flush()
        XCTAssertLessThanOrEqual(history.samples.count, BatteryHistory.maximumSamples)
        XCTAssertTrue(history.samples.allSatisfy { clock.timeIntervalSince($0.date) <= BatteryHistory.retention })
        let restored = BatteryHistoryStore(defaults: defaults, now: { clock })
        XCTAssertEqual(restored.samples, history.samples)
    }

    func testInvalidDataAndClockRollbackAreHandled() throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let history = BatteryHistoryStore(now: { clock })
        history.record(.unavailable)
        history.record(status(101))
        XCTAssertTrue(history.samples.isEmpty)
        history.record(status(80))
        clock.addTimeInterval(-60)
        history.record(status(79))
        XCTAssertEqual(history.samples.count, 1)
        XCTAssertEqual(history.samples.first?.date, clock)
        let bad = [BatteryHistorySample(date: clock, percentage: -1, pluggedIn: false),
                   BatteryHistorySample(date: clock.addingTimeInterval(1), percentage: 50, pluggedIn: false)]
        XCTAssertTrue(BatteryHistory.validated(bad, now: clock).isEmpty)
    }

    func testConsumptionNeedsAContinuousUnpluggedHour() {
        let now = Date()
        let hour = (0...60).map { i in
            BatteryHistorySample(date: now.addingTimeInterval(Double(i - 60) * 60), percentage: 90 - i / 5, pluggedIn: false)
        }
        XCTAssertEqual(BatteryHistory.consumedLastHour(hour, now: now), 12)
        XCTAssertNil(BatteryHistory.consumedLastHour(Array(hour.suffix(10)), now: now))
        XCTAssertNil(BatteryHistory.consumedLastHour(hour, now: now.addingTimeInterval(600)))
        var changed = hour
        changed[30] = BatteryHistorySample(date: hour[30].date, percentage: 84, pluggedIn: true)
        XCTAssertNil(BatteryHistory.consumedLastHour(changed, now: now))
        let gap = hour.enumerated().filter { !(20...40).contains($0.offset) }.map(\.element)
        XCTAssertNil(BatteryHistory.consumedLastHour(gap, now: now))
        XCTAssertGreaterThan(BatteryHistory.points(gap, now: now).last!.segment, 0)
    }

    private func status(_ value: Int, plugged: Bool = false) -> BatteryStatus {
        BatteryStatus(percentage: value, isCharging: plugged, isPluggedIn: plugged, isFullyCharged: false, isAvailable: true)
    }
}
