import Foundation

enum StatusAccessibilitySummary {
    static func text(for status: SystemStatus, language: AppLanguage = AppLocalization.language) -> String {
        func string(_ key: String, _ arguments: CVarArg...) -> String {
            let format = AppLocalization.string(key, language: language)
            return arguments.isEmpty ? format : String(format: format, locale: language.locale, arguments: arguments)
        }

        let network: String
        switch status.network.transport {
        case .ethernet:
            network = string(status.network.isConnected ? "Ethernet connected" : "Ethernet disconnected")
        case .wifi:
            network = string(status.network.isConnected ? "Wi-Fi connected" : "Wi-Fi disconnected")
        case .other, .none:
            network = string(status.network.isConnected ? "Network connected" : "Network disconnected")
        }

        let volume: String
        if status.audio.volume.isMuted {
            volume = string("volume muted")
        } else {
            volume = status.audio.volume.percentage.map { string("volume %d percent", $0) } ?? string("volume unavailable")
        }
        let battery = status.battery.percentage.map { string("battery %d percent", $0) } ?? string("battery unavailable")
        return string("%@, %@, %@", network, volume, battery)
    }
}
