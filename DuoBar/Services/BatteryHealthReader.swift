import IOKit

enum BatteryHealthReader {
    static func read() async -> BatteryHealthSnapshot {
        guard !Task.isCancelled else { return .unavailable }
        let worker = Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return BatteryHealthSnapshot.unavailable }
            return readRegistry()
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func readRegistry() -> BatteryHealthSnapshot {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return .unavailable }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard !Task.isCancelled,
              IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let data = properties?.takeRetainedValue() as? [String: Any] else {
            return .unavailable
        }

        #if arch(x86_64)
        return BatteryHealthSnapshot.decode(data, allowsLegacyMaximum: true)
        #else
        return BatteryHealthSnapshot.decode(data, allowsLegacyMaximum: false)
        #endif
    }
}
