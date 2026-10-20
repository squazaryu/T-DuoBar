import SwiftUI

struct GeneralSettingsView: View {
    var onPreviewPopover: (() -> Void)? = nil
    @AppStorage(PreferenceKeys.language) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(PreferenceKeys.popoverStyle) private var popoverStyleRaw = PopoverStyle.classic.rawValue
    @AppStorage(PreferenceKeys.popoverTransparency) private var popoverTransparency = PopoverAppearance.defaultTransparency
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(PreferenceKeys.scrollToAdjustVolume) private var scrollToAdjustVolume = false
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.menuBarIconScale) private var iconScale = MenuBarIconSize.defaultScale
    @AppStorage(PreferenceKeys.menuBarBatteryPercentage) private var menuBarBatteryPercentage = false
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.showBatteryTime) private var showBatteryTime = true
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false
    @AppStorage(PreferenceKeys.openOnHover) private var openOnHover = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    private let deviceContext = DeviceContextService().current()
    #if DEBUG
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    @State private var showsDiagnostics = false
    #endif

    var body: some View {
        Form {
            Section(localized("Appearance")) {
                Picker(localized("Language"), selection: Binding(
                    get: { (AppLanguage(rawValue: languageRaw) ?? .system).rawValue },
                    set: { languageRaw = $0 })) {
                    ForEach(AppLanguage.allCases) { language in Text(language.name).tag(language.rawValue) }
                }
                Picker(localized("Pop-up appearance"), selection: popoverStyle) {
                    ForEach(PopoverStyle.allCases) { style in
                        Text(style.title).tag(style)
                            .disabled(style == .liquidGlass && !PopoverStyle.supportsLiquidGlass)
                    }
                }
                if !PopoverStyle.supportsLiquidGlass {
                    Text(localized("Liquid Glass requires macOS 26 or later."))
                        .font(.caption).foregroundStyle(.secondary)
                } else if popoverStyle.wrappedValue == .liquidGlass {
                    LabeledContent(localized("Background transparency")) {
                        HStack(spacing: 10) {
                            Slider(value: resolvedTransparency, in: 0...1, step: 0.05)
                                .accessibilityLabel(localized("Background transparency"))
                                .accessibilityValue(transparencyLabel)
                            Text(transparencyLabel).monospacedDigit()
                                .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                        }.frame(width: 220)
                    }
                    .disabled(reduceTransparency)
                    Text(localized(reduceTransparency
                        ? "Reduce Transparency is enabled in macOS. The menu uses an opaque background."
                        : "Text and controls stay opaque. macOS manages the glass effect."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let onPreviewPopover {
                    Button(localized("Preview menu"), action: onPreviewPopover)
                }
                if showsBatteryRingSettings {
                    Toggle(localized("Battery percentage in menu bar"), isOn: $menuBarBatteryPercentage)
                    if menuBarBatteryPercentage {
                        Text(localized("For clearer digits, set Icon Size to 100% or 105%."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(localized("Show battery percentage in popover"), isOn: $showBatteryPercentage)
                Toggle(localized("Enable animations"), isOn: $animationsEnabled)
                LabeledContent(localized("Icon Size")) {
                    HStack(spacing: 10) {
                        Slider(value: resolvedIconScale, in: MenuBarIconSize.minimumScale...MenuBarIconSize.maximumScale,
                            step: MenuBarIconSize.step)
                            .accessibilityLabel(localized("Menu bar icon size"))
                            .accessibilityValue(localized("%d%%", Int((MenuBarIconSize.resolve(iconScale) * 100).rounded())))
                        Text(localized("%d%%", Int((MenuBarIconSize.resolve(iconScale) * 100).rounded())))
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }.frame(width: 220)
                }
            }

            MenuSectionsSettingsView()

            Section(localized("Battery")) {
                Toggle(localized("Show battery time"), isOn: $showBatteryTime)
                if showsBatteryRingSettings {
                    Toggle(localized("Battery Color Coding"), isOn: $batteryColorCoding)
                }
            }

            if showsAdaptiveRingSettings {
                Section(localized("Adaptive Ring")) {
                    Picker(localized("Adaptive Ring Priority"), selection: adaptiveRingPriority) {
                        ForEach(PerformancePreference.allCases, id: \.self) { preference in
                            Text(preference.localizedDisplayName).tag(preference)
                        }
                    }
                    Text(localized("Used only when multiple system conditions need attention. Critical conditions can still take priority."))
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle(localized("Adaptive Ring Color Coding"), isOn: $adaptiveRingColorCoding)
                }
            }

            Section(localized("Behavior")) {
                Toggle(localized("Adjust volume by scrolling over the icon"), isOn: $scrollToAdjustVolume)
                    .help(localized("Scroll up to raise volume, down to lower it. Trackpad momentum is ignored."))
                Toggle(localized("Open on Hover"), isOn: $openOnHover)
                    .help(localized("Open DuoBar when the pointer moves over the menu bar icon."))
                Toggle(localized("Launch DuoBar at login"), isOn: Binding(
                    get: { launchAtLogin.isEnabled }, set: launchAtLogin.setEnabled))
                if launchAtLogin.requiresApproval {
                    Text(localized("Approval is required in System Settings → General → Login Items."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = launchAtLogin.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
            }

            #if DEBUG
            if !MarketingCaptureMode.isEnabled {
                Section {
                    DisclosureGroup(localized("Developer diagnostics"), isExpanded: $showsDiagnostics) {
                        if showsDiagnostics {
                            DebugPerformanceDiagnosticsView()
                            DebugDuoGlyphTuningView()
                        }
                    }
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.small)
        .onAppear {
            launchAtLogin.refresh()
            if showsAdaptiveRingSettings { adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue) }
        }
        .onChange(of: adaptiveRingPriorityRaw) { _ in
            if showsAdaptiveRingSettings { adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue) }
        }
    }

    private var resolvedIconScale: Binding<Double> {
        Binding(get: { MenuBarIconSize.resolve(iconScale) }, set: { iconScale = MenuBarIconSize.resolve($0) })
    }

    private var popoverStyle: Binding<PopoverStyle> {
        Binding(get: { PopoverStyle(rawValue: popoverStyleRaw) ?? .classic },
            set: { popoverStyleRaw = $0.rawValue })
    }

    private var resolvedTransparency: Binding<Double> {
        Binding(get: { PopoverAppearance.resolveTransparency(popoverTransparency) },
            set: { popoverTransparency = PopoverAppearance.resolveTransparency($0) })
    }

    private var transparencyLabel: String {
        localized("%d%%", Int((resolvedTransparency.wrappedValue * 100).rounded()))
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue })
    }

    private var showsAdaptiveRingSettings: Bool {
        #if DEBUG
        AdaptiveRingSettingsEligibility.isEligible(for: deviceContext, simulateDesktop: simulateDesktopMac)
        #else
        AdaptiveRingSettingsEligibility.isEligible(for: deviceContext)
        #endif
    }

    private var showsBatteryRingSettings: Bool {
        #if DEBUG
        !simulateDesktopMac && deviceContext.ringBehavior == .batteryRing
        #else
        deviceContext.ringBehavior == .batteryRing
        #endif
    }
}
