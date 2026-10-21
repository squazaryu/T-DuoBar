import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

/// Reproducible documentation images from production views with demo values.
final class RepositoryArtworkTests: XCTestCase {
    @MainActor
    func testRenderRepositoryArtwork() async throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("T-DuoBar-RepositoryArtwork", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let defaults = UserDefaults.standard
        let previousLanguage = defaults.object(forKey: PreferenceKeys.language)
        let suiteName = "RepositoryArtwork.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            if let previousLanguage { defaults.set(previousLanguage, forKey: PreferenceKeys.language) }
            else { defaults.removeObject(forKey: PreferenceKeys.language) }
            preferences.removePersistentDomain(forName: suiteName)
        }
        defaults.set("en", forKey: PreferenceKeys.language)
        preferences.set("en", forKey: PreferenceKeys.language)
        preferences.set(true, forKey: PreferenceKeys.menuBarBatteryPercentage)
        preferences.set(true, forKey: PreferenceKeys.batteryColorCoding)
        preferences.set(false, forKey: PreferenceKeys.showMicrophone)
        preferences.set(false, forKey: PreferenceKeys.hideEmptyAccessories)
        preferences.set(MenuSectionOrder.defaultValue, forKey: PreferenceKeys.menuSectionOrder)
        preferences.set(PopoverStyle.liquidGlass.rawValue, forKey: PreferenceKeys.popoverStyle)
        preferences.set(0.65, forKey: PreferenceKeys.popoverTransparency)
        let vpn = VPNStatusService(reader: {
            VPNStatus(connections: [VPNConnection(id: "demo", name: "Demo VPN", state: .connected, interfaceName: "utun0")])
        }, monitor: TestVPNChangeMonitor())
        vpn.start()
        defer { vpn.stop() }
        for _ in 0..<50 where vpn.isRefreshing { try await Task.sleep(for: .milliseconds(10)) }
        let store = SystemStatusStore(startServices: false, vpnStatusService: vpn)
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 72, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108))
        store.applyMarketingCaptureState("hero")
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 72, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108))
        store.applyDebugVolumeState(.fiftyOne)
        for (name, scheme, appearance) in [("light", ColorScheme.light, NSAppearance.Name.aqua),
                                          ("dark", ColorScheme.dark, NSAppearance.Name.darkAqua)] {
            try write(StatusPopoverView(statusStore: store, onClose: {}).content
                .padding(12).background(Color(nsColor: .windowBackgroundColor))
                .defaultAppStorage(preferences).environment(\.colorScheme, scheme),
                to: output.appendingPathComponent("popup-\(name).png"), appearance: appearance)
        }
        try write(GeneralSettingsView(onPreviewPopover: {}).defaultAppStorage(preferences)
            .frame(width: 560, height: 590).background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .dark), to: output.appendingPathComponent("settings-general.png"))
        let icon = try XCTUnwrap(NSApp.applicationIconImage)
        let hero = HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 20) {
                Image(nsImage: icon).resizable().frame(width: 88, height: 88)
                Text("T-DuoBar").font(.system(size: 42, weight: .bold, design: .rounded))
                Text("Battery. Network. Audio.").font(.system(size: 21, weight: .medium))
                Text("A little more control.\nOne place in your menu bar.")
                    .font(.system(size: 17)).foregroundStyle(.secondary)
                HStack(spacing: 32) {
                    DuoGlyphView(status: store.status, metrics: .standard.sized(80), animationsEnabled: false,
                        batteryColorCodingEnabled: true)
                    DuoGlyphView(status: store.status, metrics: .standard.sized(80), animationsEnabled: false,
                        batteryColorCodingEnabled: true, showsBatteryPercentage: true)
                }.padding(.vertical, 6)
                Text("Classic or Liquid Glass · 6 languages")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("A community fork of DuoBar").font(.system(size: 12)).foregroundStyle(.secondary)
            }.frame(width: 320, alignment: .leading)
            StatusPopoverView(statusStore: store, onClose: {}).content
                .defaultAppStorage(preferences).padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(40)
        .background(Color(red: 0.035, green: 0.045, blue: 0.065))
        .environment(\.colorScheme, .dark)
        try write(hero, to: output.appendingPathComponent("t-duobar-hero.png"))
    }

    @MainActor
    private func write<Content: View>(_ content: Content, to url: URL,
                                     appearance: NSAppearance.Name = .darkAqua) throws {
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url, options: .atomic)
        XCTAssertGreaterThan(png.count, 1_000)
    }
}
