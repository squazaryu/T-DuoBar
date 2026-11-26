import Foundation
import IOKit
import IOKit.ps

enum AccessoryBatteryFallbacks {
    static func fillMissingLevels(
        _ connected: [AccessoryBattery],
        readHID: (Set<String>) -> [String: Int],
        readPowerSources: () -> [String: Int]
    ) -> [AccessoryBattery] {
        let missing = connected.filter { $0.percentage == nil }
        guard !missing.isEmpty else { return connected }
        let addresses = Set(missing.compactMap(\.bluetoothAddress))
        let hidLevels = addresses.isEmpty ? [:] : readHID(addresses)
        var result = connected
        for index in result.indices where result[index].percentage == nil {
            if let address = result[index].bluetoothAddress, let level = hidLevels[address] {
                result[index].levels["main"] = level
            }
        }
        guard result.contains(where: { $0.percentage == nil }) else { return result }

        // pmset has no Bluetooth address. A name must be unique among all
        // connected devices, including devices that already have a reading.
        let grouped = Dictionary(grouping: connected, by: { nameKey($0.name) })
        let candidates = result.indices.filter {
            result[$0].percentage == nil && grouped[nameKey(result[$0].name)]?.count == 1
        }
        guard !candidates.isEmpty else { return result }
        let powerLevels = readPowerSources()
        for index in candidates {
            result[index].levels["main"] = powerLevels[nameKey(result[index].name)]
        }
        return result
    }

    static func readHIDLevels(for addresses: Set<String>) -> [String: Int] {
        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
            IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return [:] }
        defer { IOObjectRelease(iterator) }

        var readings: [String: Set<Int>] = [:]
        while !Task.isCancelled {
            let service = IOIteratorNext(iterator)
            guard service != IO_OBJECT_NULL else { break }
            defer { IOObjectRelease(service) }
            guard registryProperty(service, "Transport") as? String == "Bluetooth",
                  let address = AccessoryBatteryParser.normalizedAddress(registryProperty(service, "DeviceAddress") as? String),
                  addresses.contains(address),
                  let level = AccessoryBatteryParser.percentage(registryProperty(service, "BatteryPercent")) else { continue }
            readings[address, default: []].insert(level)
        }
        return readings.compactMapValues { $0.count == 1 ? $0.first : nil }
    }

    static func powerLevels(in report: Data, excluding names: Set<String>) -> [String: Int] {
        guard let output = String(data: report, encoding: .utf8) else { return [:] }
        let sourceLine = #/[ \t]*-(.+) \(id=-?[0-9]+\)\t([^\t]*) present: true[ \t]*/#
        let percentagePrefix = #/([0-9]{1,3})%;/#
        let excluded = Set(names.map(nameKey))
        var seenNames = Set<String>()
        var readings: [String: Int] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let match = line.wholeMatch(of: sourceLine) else { continue }
            let name = nameKey(match.1)
            guard !name.isEmpty, !excluded.contains(name) else { continue }
            if seenNames.insert(name).inserted, let charge = match.2.prefixMatch(of: percentagePrefix) {
                readings[name] = AccessoryBatteryParser.percentage(String(charge.1))
            } else {
                readings.removeValue(forKey: name)
            }
        }
        return readings
    }

    static func systemPowerSourceNames() -> Set<String> {
        // The public power-source list describes the Mac and any UPS.
        // Exclude those names because pmset includes their batteries as well.
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
        return Set(sources.compactMap { source in
            let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSNameKey] as? String
        })
    }

    private static func registryProperty(_ service: io_service_t, _ key: String) -> CFTypeRef? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func nameKey<S: StringProtocol>(_ name: S) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
