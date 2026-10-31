import Foundation

struct BatteryHistorySample: Codable, Equatable, Identifiable {
    let date: Date
    let percentage: Int
    let pluggedIn: Bool
    var id: Date { date }
}

struct BatteryHistoryPoint: Identifiable {
    let sample: BatteryHistorySample
    let segment: Int
    var id: Date { sample.date }
}

enum BatteryHistory {
    static let retention: TimeInterval = 24 * 60 * 60
    static let maximumSamples = 1500

    static func validated(_ samples: [BatteryHistorySample], now: Date) -> [BatteryHistorySample] {
        var seen = Set<Date>()
        return Array(samples.filter {
            (0...100).contains($0.percentage) && $0.date <= now
                && now.timeIntervalSince($0.date) <= retention && seen.insert($0.date).inserted
        }.sorted { $0.date < $1.date }.suffix(maximumSamples))
    }

    static func points(_ samples: [BatteryHistorySample], now: Date) -> [BatteryHistoryPoint] {
        let visible = samples.filter { now.timeIntervalSince($0.date) <= 6 * 3600 }
        var segment = 0
        return visible.enumerated().map { index, sample in
            if index > 0 {
                let previous = visible[index - 1]
                if sample.pluggedIn != previous.pluggedIn || sample.date.timeIntervalSince(previous.date) > 5 * 60 { segment += 1 }
            }
            return BatteryHistoryPoint(sample: sample, segment: segment)
        }
    }

    /// Never extrapolate a short session or bridge charging/sleep gaps.
    static func consumedLastHour(_ samples: [BatteryHistorySample], now: Date) -> Int? {
        guard let last = samples.last, !last.pluggedIn, now.timeIntervalSince(last.date) <= 5 * 60 else { return nil }
        let target = last.date.addingTimeInterval(-3600)
        guard let first = samples.min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }),
              abs(first.date.timeIntervalSince(target)) <= 90 else { return nil }
        let hour = samples.filter { $0.date >= first.date }
        guard hour.allSatisfy({ !$0.pluggedIn }), hour.count > 1 else { return nil }
        for (a, b) in zip(hour, hour.dropFirst()) {
            guard b.date.timeIntervalSince(a.date) <= 5 * 60, b.percentage <= a.percentage + 1 else { return nil }
        }
        let consumed = first.percentage - last.percentage
        return consumed >= 0 ? consumed : nil
    }
}
