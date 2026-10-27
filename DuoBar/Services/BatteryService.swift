import Foundation
import IOKit.ps

@MainActor
final class BatteryService {
    var onStatusChange: ((BatteryStatus) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var fallbackTimer: Timer?
    private var lastStatus: BatteryStatus?
    private var lowPowerModeObserver: NSObjectProtocol?

    func start() {
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                #if DEBUG
                NSLog("[BatteryService] power source changed")
                #endif
                service.refresh(trigger: .notification)
            }
        }, context).takeRetainedValue()

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        let fallbackTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(trigger: .fallback)
            }
        }
        fallbackTimer.tolerance = 6
        self.fallbackTimer = fallbackTimer
        RunLoop.main.add(fallbackTimer, forMode: .common)

        lowPowerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: ProcessInfo.processInfo,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(trigger: .lowPowerModeChanged)
            }
        }

        refresh(trigger: .initial)
    }

    func refresh() {
        refresh(trigger: .manual)
    }

    private func refresh(trigger: RefreshTrigger) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            publish(.unavailable, trigger: trigger)
            return
        }

        let descriptions = sources.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        guard let dictionary = BatteryPowerSourceStatusMapper.internalBattery(in: descriptions)
        else {
            publish(.unavailable, trigger: trigger)
            return
        }

        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        publish(
            BatteryPowerSourceStatusMapper.status(
                dictionary: dictionary,
                adapterWatts: adapter?[kIOPSPowerAdapterWattsKey] as? Int,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            ),
            trigger: trigger
        )
    }

    private func publish(_ status: BatteryStatus, trigger: RefreshTrigger) {
        let previous = lastStatus
        guard status != previous else { return }
        lastStatus = status

        #if DEBUG
        let percentage = status.percentage.map { "\($0)%" } ?? "unavailable"
        NSLog("%@", "[BatteryService] battery = \(percentage), charging = \(status.isCharging), pluggedIn = \(status.isPluggedIn), time = \(status.remainingTimeMinutes.map(String.init) ?? "unavailable"), source = \(trigger.rawValue)")
        if let previous, previous.isCharging != status.isCharging {
            NSLog("%@", "[BatteryService] charging changed: \(previous.isCharging) → \(status.isCharging)")
        }
        #endif

        onStatusChange?(status)
    }

    deinit {
        fallbackTimer?.invalidate()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let lowPowerModeObserver {
            NotificationCenter.default.removeObserver(lowPowerModeObserver)
        }
    }

    private enum RefreshTrigger: String {
        case initial
        case notification
        case manual
        case fallback
        case lowPowerModeChanged
    }
}
