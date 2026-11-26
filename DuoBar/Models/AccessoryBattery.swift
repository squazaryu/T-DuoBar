import Foundation

struct AccessoryBattery: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var levels: [String: Int]
    var bluetoothAddress: String? = nil
    var deviceMinorType: String? = nil

    var percentage: Int? {
        let earbuds = [levels["left"], levels["right"]].compactMap { $0 }
        return earbuds.min() ?? levels["main"] ?? levels["case"]
    }

    var symbol: String {
        let name = name.lowercased()
        switch deviceMinorType?.lowercased() {
        case "headset", "headphones": return headphoneSymbol
        case "mouse": return "computermouse"
        case "trackpad": return "trackpad"
        case "keyboard": return "keyboard"
        case "loudspeaker", "speaker": return "speaker.wave.2"
        case "gamepad", "joystick": return "gamecontroller"
        default: break
        }
        if name.contains("keyboard") { return "keyboard" }
        if name.contains("mouse") { return "computermouse" }
        if name.contains("trackpad") { return "trackpad" }
        if name.contains("headphone") || name.contains("headset") || name.contains("airpods") { return headphoneSymbol }
        return "wave.3.right"
    }

    private var headphoneSymbol: String {
        let name = name.lowercased()
        return name.contains("airpods") && !name.contains("airpods max") ? "airpodspro" : "headphones"
    }
}

enum AccessoryBatteryParser {
    static func percentage(_ value: Any?) -> Int? {
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
        let number: Int?
        if let value = value as? String {
            number = Int(value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        } else { number = value as? Int }
        return number.flatMap { (0...100).contains($0) ? $0 : nil }
    }

    static func normalizedAddress(_ address: String?) -> String? {
        guard let address else { return nil }
        let octets = address.split(omittingEmptySubsequences: false, whereSeparator: { $0 == ":" || $0 == "-" })
        guard octets.count == 6,
              octets.allSatisfy({ $0.utf8.count == 2 && $0.allSatisfy(\.isHexDigit) }) else { return nil }
        return octets.joined().lowercased()
    }

    static func parse(_ data: Data) throws -> [AccessoryBattery] {
        let object = try JSONSerialization.jsonObject(with: data)
        var found: [AccessoryBattery] = []
        func connectedDevices(_ list: [Any]) {
            for item in list {
                guard let entry = item as? [String: Any] else { continue }
                for (name, value) in entry {
                    guard let fields = value as? [String: Any] else { continue }
                    var levels: [String: Int] = [:]
                    for (key, raw) in fields where key.lowercased().contains("batterylevel") {
                        guard let value = percentage(raw) else { continue }
                        let key = key.lowercased()
                        let component = key.contains("left") ? "left" : key.contains("right") ? "right" : key.contains("case") ? "case" : "main"
                        levels[component] = value
                    }
                    let address = fields["device_address"] as? String
                    found.append(AccessoryBattery(id: address ?? name, name: name, levels: levels,
                        bluetoothAddress: normalizedAddress(address), deviceMinorType: fields["device_minorType"] as? String))
                }
            }
        }
        func visit(_ object: Any) {
            if let dictionary = object as? [String: Any] {
                for (key, value) in dictionary {
                    // Never present cached readings from disconnected accessories.
                    if key == "device_connected", let list = value as? [Any] { connectedDevices(list) }
                    else if key != "device_not_connected" { visit(value) }
                }
            } else if let list = object as? [Any] { list.forEach(visit) }
        }
        visit(object)
        var seen = Set<String>()
        return found.filter { seen.insert($0.bluetoothAddress ?? $0.id.lowercased()).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum AudioFavorites {
    static func decode(_ raw: String) -> Set<String> {
        guard let data = raw.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(values.filter { !$0.isEmpty })
    }
    static func encode(_ values: Set<String>) -> String {
        guard let data = try? JSONEncoder().encode(values.sorted()) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}
