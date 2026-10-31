import Combine
import Foundation

@MainActor
final class BatteryHistoryStore: ObservableObject {
    @Published private(set) var samples: [BatteryHistorySample]
    private let defaults: UserDefaults?
    private let now: () -> Date
    private var lastSaved: Date?
    private var hasChanges = false
    private static let key = "battery.history.v1"

    init(defaults: UserDefaults? = nil, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults?.data(forKey: Self.key), data.count <= 256 * 1024,
           let saved = try? JSONDecoder().decode([BatteryHistorySample].self, from: data) {
            samples = BatteryHistory.validated(saved, now: now())
        } else { samples = [] }
    }

    func record(_ battery: BatteryStatus) {
        guard battery.isAvailable, let percentage = battery.percentage, (0...100).contains(percentage) else { return }
        let date = now()
        if let last = samples.last, date >= last.date,
           date.timeIntervalSince(last.date) < 60, last.pluggedIn == battery.isPluggedIn { return }
        var history = BatteryHistory.validated(samples, now: date)
        if let last = history.last {
            guard date > last.date else { return }
            if date.timeIntervalSince(last.date) < 60, last.pluggedIn == battery.isPluggedIn { return }
        }
        history.append(BatteryHistorySample(date: date, percentage: percentage, pluggedIn: battery.isPluggedIn))
        samples = Array(history.suffix(BatteryHistory.maximumSamples))
        hasChanges = true
        // Collect from existing battery callbacks, persist at most every 15 min
        // plus power-source changes and normal termination. No polling timer.
        if lastSaved == nil || (lastSaved.map { date.timeIntervalSince($0) >= 15 * 60 } ?? true)
            || history.dropLast().last?.pluggedIn != battery.isPluggedIn { flush() }
    }

    func flush() {
        guard hasChanges, let defaults, let data = try? JSONEncoder().encode(samples) else { return }
        defaults.set(data, forKey: Self.key)
        lastSaved = now()
        hasChanges = false
    }
}
