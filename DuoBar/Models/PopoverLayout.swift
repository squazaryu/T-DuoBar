import SwiftUI

/// Content density is independent of the pop-up's background material.
enum PopoverLayout: String, CaseIterable, Identifiable {
    case standard
    case compact

    var id: String { rawValue }
    var title: String { localized(self == .standard ? "Standard" : "Compact") }

    static func resolve(_ raw: String?) -> Self { raw.flatMap(Self.init(rawValue:)) ?? .standard }
}

private struct PopoverLayoutKey: EnvironmentKey {
    static let defaultValue = PopoverLayout.standard
}

extension EnvironmentValues {
    var popoverLayout: PopoverLayout {
        get { self[PopoverLayoutKey.self] }
        set { self[PopoverLayoutKey.self] = newValue }
    }
}
