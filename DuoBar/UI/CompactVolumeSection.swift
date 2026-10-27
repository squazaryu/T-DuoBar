import SwiftUI

struct CompactVolumeSection: View {
    let volume: OutputVolumeStatus
    let hasOutputDevice: Bool
    let playbackDeviceIdentifier: String?
    let onSetVolume: (Double) -> Bool
    let onSetMuted: (Bool) -> Bool
    let onOpenSettings: () -> Void
    var initiallyExpanded = false

    var body: some View {
        StatusDetailSection(initiallyExpanded: initiallyExpanded,
            settingsTitle: localized("Sound Settings…"), onOpenSettings: onOpenSettings) {
            CompactStatusRow(symbol: volume.isMuted ? "speaker.slash" : "speaker.wave.2",
                title: localized("Volume"), value: summary)
        } content: {
            // Reuse the existing slider/mute interaction, including feedback and
            // hardware-controlled volume handling, rather than creating a second path.
            VolumeStatusRow(volume: volume, hasOutputDevice: hasOutputDevice,
                playbackDeviceIdentifier: playbackDeviceIdentifier,
                onSetVolume: onSetVolume, onSetMuted: onSetMuted, drawsBackground: false, controlsOnly: true)
        }
    }

    private var summary: String {
        guard hasOutputDevice else { return localized("Volume unavailable") }
        if volume.isMuted { return localized("Muted") }
        return volume.percentage.map { localized("%d%%", $0) }
            ?? localized("Controlled by device")
    }
}
