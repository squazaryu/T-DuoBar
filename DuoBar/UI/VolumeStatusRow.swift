import SwiftUI

struct VolumeStatusRow: View {
    @Environment(\.menuTypography) private var typography
    let volume: OutputVolumeStatus
    let hasOutputDevice: Bool
    let playbackDeviceIdentifier: String?
    let onSetVolume: (Double) -> Bool
    let onSetMuted: (Bool) -> Bool
    var drawsBackground = true
    var controlsOnly = false

    @State private var feedbackInteraction = VolumeFeedbackInteraction()

    @ViewBuilder
    var body: some View {
        if controlsOnly {
            HStack(spacing: 8) {
                muteControl.frame(width: 28, height: 28)
                volumeControl
            }
            .frame(minHeight: 28)
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        HStack(spacing: 11) {
            muteControl
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                StatusRowHeader(title: localized("Volume"), value: stateText)

                volumeControl
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: typography.readable ? 62 : 54)
        .background(.primary.opacity(drawsBackground ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var volumeControl: some View {
        if volume.isSettable, let level = volume.level {
            Slider(
                value: Binding(
                    get: { level },
                    set: handleUserVolumeChange
                ),
                in: 0...1,
                onEditingChanged: handleSliderEditingChanged
            )
            .controlSize(.mini)
            .accessibilityLabel(localized("Output volume"))
            .accessibilityValue(stateText)
        } else {
            Text(hasOutputDevice ? localized("Controlled by device") : localized("Volume unavailable"))
                .font(.system(size: typography.size(10.5)))
                .foregroundStyle(typography.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    @ViewBuilder
    private var muteControl: some View {
        if volume.isMuteSettable {
            Button {
                handleUserMuteChange()
            } label: {
                Image(systemName: volumeSymbol)
                    .font(.system(size: typography.size(13), weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(volume.isMuted ? localized("Unmute") : localized("Mute"))
            .accessibilityLabel(volume.isMuted ? localized("Unmute output") : localized("Mute output"))
        } else {
            Image(systemName: volumeSymbol)
                .font(.system(size: typography.size(13), weight: .semibold))
        }
    }

    private var volumeSymbol: String {
        guard let percentage = volume.percentage else { return "speaker" }
        if volume.isMuted || percentage == 0 { return "speaker.slash.fill" }
        switch percentage {
        case 1...33: return "speaker.wave.1"
        case 34...66: return "speaker.wave.2"
        default: return "speaker.wave.3"
        }
    }

    private var stateText: String {
        if volume.isMuted { return localized("Muted") }
        return volume.percentage.map { localized("%d%%", $0) } ?? "—"
    }

    private func handleUserVolumeChange(_ level: Double) {
        beginSliderInteractionIfNeeded()
        guard feedbackInteraction.allowsVolumeUpdates else {
            feedbackInteraction.recordVolumeUpdate(
                previousStatus: volume,
                requestedLevel: level,
                writeSucceeded: false
            )
            return
        }

        let writeSucceeded = onSetVolume(level)
        feedbackInteraction.recordVolumeUpdate(
            previousStatus: volume,
            requestedLevel: level,
            writeSucceeded: writeSucceeded
        )
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            beginSliderInteractionIfNeeded()
            return
        }
        guard feedbackInteraction.endEditing() else { return }
        VolumeFeedbackSound.play(on: playbackDeviceIdentifier)
    }

    private func beginSliderInteractionIfNeeded() {
        feedbackInteraction.beginEditing(previousStatus: volume) {
            onSetMuted(false)
        }
    }

    private func handleUserMuteChange() {
        let writeSucceeded = onSetMuted(!volume.isMuted)
        guard feedbackInteraction.shouldPlayForUnmute(
            previousStatus: volume,
            writeSucceeded: writeSucceeded
        ) else { return }

        VolumeFeedbackSound.play(on: playbackDeviceIdentifier)
    }
}
