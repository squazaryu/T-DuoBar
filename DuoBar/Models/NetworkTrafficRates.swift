struct NetworkTrafficRates: Equatable, Sendable {
    let receiveBytesPerSecond: Double
    let sendBytesPerSecond: Double
}

struct NetworkTrafficSample: Sendable {
    let interfaceIndex: Int32
    let interfaceChangeTime: Int64
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let time: ContinuousClock.Instant
    let awakeTime: SuspendingClock.Instant

    func rates(since previous: NetworkTrafficSample) -> NetworkTrafficRates? {
        guard interfaceIndex == previous.interfaceIndex,
              interfaceChangeTime == previous.interfaceChangeTime else { return nil }

        let interval = previous.time.duration(to: time)
        let awakeInterval = previous.awakeTime.duration(to: awakeTime)
        guard interval >= .milliseconds(500), interval <= .seconds(3),
              awakeInterval > .zero, interval - awakeInterval < .milliseconds(250) else { return nil }

        let components = interval.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        let receive = Double(receivedBytes &- previous.receivedBytes) / seconds
        let send = Double(sentBytes &- previous.sentBytes) / seconds
        // With 64-bit counters, a reset looks like an enormous modular delta.
        // This 400 Gbit/s ceiling also leaves room for fast external interfaces.
        let maximumBytesPerSecond = 50_000_000_000.0
        guard receive <= maximumBytesPerSecond, send <= maximumBytesPerSecond else { return nil }
        return NetworkTrafficRates(receiveBytesPerSecond: receive, sendBytesPerSecond: send)
    }
}
