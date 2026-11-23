import SwiftUI

struct MenuExperienceSettingsView: View {
    @AppStorage(PreferenceKeys.widePopover) private var wide = false
    @AppStorage(PreferenceKeys.highlightMenuRows) private var highlight = false
    @AppStorage(PreferenceKeys.readableMenuText) private var readable = false
    @AppStorage(PreferenceKeys.singleExpandedSection) private var single = false
    @AppStorage(PreferenceKeys.networkDiagnostics) private var diagnostics = false
    @AppStorage(PreferenceKeys.showNetworkTraffic) private var traffic = false

    var body: some View {
        Section(localized("Menu options")) {
            Toggle(localized("Wider pop-up"), isOn: $wide)
            Toggle(localized("Highlight menu rows"), isOn: $highlight)
            Toggle(localized("Larger, higher-contrast menu text"), isOn: $readable)
            Toggle(localized("Expand one section at a time"), isOn: $single)
            Toggle(localized("Show network diagnostics"), isOn: $diagnostics)
            Text(localized("Diagnostics run only when you press Check connection. No background checks."))
                .font(.caption).foregroundStyle(.secondary)
            Toggle(localized("Show live network traffic"), isOn: $traffic)
                .help(localized("Measures the active interface while Network is expanded."))
        }
    }
}
