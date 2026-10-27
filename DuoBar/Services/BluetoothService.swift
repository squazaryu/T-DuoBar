import Foundation
import IOBluetooth

@MainActor
final class BluetoothService {
    var onStatusChange: ((BluetoothStatus) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private let worker = DispatchQueue(label: "T-DuoBar.BluetoothStatus", qos: .utility)
    private let readStatus: @Sendable () -> BluetoothStatus
    private var reading = false
    private var refreshPending = false

    init(readStatus: @escaping @Sendable () -> BluetoothStatus = { BluetoothService.readSystemStatus() }) {
        self.readStatus = readStatus
    }

    func start() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        let names = [
            Notification.Name.IOBluetoothHostControllerPoweredOn,
            Notification.Name.IOBluetoothHostControllerPoweredOff
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        refresh()
    }

    func refresh() {
        guard !reading else { refreshPending = true; return }
        reading = true
        let reader = readStatus
        worker.async { [weak self] in
            // IOBluetooth's first controller lookup can block while its internal
            // CoreBluetooth coordinator starts. Never hold up the app's main loop.
            let status = reader()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reading = false
                self.onStatusChange?(status)
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh()
                }
            }
        }
    }

    nonisolated private static func readSystemStatus() -> BluetoothStatus {
        guard let controller = IOBluetoothHostController.default() else {
            return .unavailable
        }

        return BluetoothStatus(isAvailable: true,
            isPoweredOn: controller.powerState == kBluetoothHCIPowerStateON)
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
