import SwiftUI

struct BatteryHealthDetails: View {
    @Environment(\.statusSectionExpanded) private var isExpanded
    private let isActive: Bool
    private let read: @Sendable () async -> BatteryHealthSnapshot

    init(isActive: Bool, read: @escaping @Sendable () async -> BatteryHealthSnapshot = { await BatteryHealthReader.read() }) {
        self.isActive = isActive
        self.read = read
    }

    var body: some View {
        if isActive && isExpanded {
            BatteryHealthReadout(read: read)
        }
    }
}

private struct BatteryHealthReadout: View {
    @Environment(\.locale) private var locale
    @Environment(\.menuTypography) private var typography
    @State private var snapshot: BatteryHealthSnapshot?
    private let read: @Sendable () async -> BatteryHealthSnapshot

    init(read: @escaping @Sendable () async -> BatteryHealthSnapshot) {
        self.read = read
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let snapshot {
                StatusDetailLine(title: "Maximum capacity", value: snapshot.maximumCapacityPercentage.map {
                    localized("%d%%", $0)
                })
                StatusDetailLine(title: "Cycle count", value: snapshot.cycleCount.map {
                    $0.formatted(.number.locale(locale))
                })
                if snapshot.maximumCapacityPercentage != nil {
                    Text(localized("Estimate based on the battery’s design capacity. macOS may report a different value."))
                        .font(.system(size: typography.size(9.5)))
                        .foregroundStyle(typography.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(localized("Reading battery health…"))
                    .foregroundStyle(typography.secondary)
            }
        }
        .task {
            guard !Task.isCancelled else { return }
            let reading = await read()
            guard !Task.isCancelled else { return }
            snapshot = reading
        }
    }
}
