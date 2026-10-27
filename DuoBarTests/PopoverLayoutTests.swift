import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class PopoverLayoutTests: XCTestCase {
    func testMissingAndUnknownPreferencesPreserveStandardLayout() {
        XCTAssertEqual(PopoverLayout.resolve(nil), .standard)
        XCTAssertEqual(PopoverLayout.resolve("unknown"), .standard)
    }

    @MainActor
    func testLivePreferenceSwitchChangesHeightAndPreservesBackgroundChoice() throws {
        let suite = "PopoverLayoutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        configure(defaults)
        defaults.set(PopoverStyle.liquidGlass.rawValue, forKey: PreferenceKeys.popoverStyle)
        let order = MenuSectionOrder.encode(MenuSection.allCases.reversed())
        defaults.set(order, forKey: PreferenceKeys.menuSectionOrder)
        let store = demoStore()
        let host = NSHostingView(rootView: StatusPopoverView(statusStore: store, onClose: {})
            .defaultAppStorage(defaults))
        let window = attach(host)
        defer { window.contentView = nil; window.close() }
        settle(host)
        let standardHeight = host.fittingSize.height
        defaults.set(PopoverLayout.compact.rawValue, forKey: PreferenceKeys.popoverLayout)
        settle(host)
        let compactHeight = host.fittingSize.height
        XCTAssertLessThan(compactHeight, standardHeight - 100)
        XCTAssertEqual(host.fittingSize.width, 304, accuracy: 0.1)
        XCTAssertEqual(PopoverAppearance(defaults: defaults).style, .liquidGlass)
        XCTAssertEqual(defaults.string(forKey: PreferenceKeys.menuSectionOrder), order)
        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.showMicrophone))
        XCTAssertEqual(PopoverLayout.resolve(UserDefaults(suiteName: suite)?.string(forKey: PreferenceKeys.popoverLayout)), .compact)
        defaults.set(PopoverLayout.standard.rawValue, forKey: PreferenceKeys.popoverLayout)
        settle(host)
        XCTAssertEqual(host.fittingSize.height, standardHeight, accuracy: 1)
    }

    @MainActor
    func testCompactHeaderGapOpensAndClosesVolumeControls() throws {
        let content = CompactVolumeSection(volume: OutputVolumeStatus(level: 0.51, isMuted: false, isSettable: true),
            hasOutputDevice: true, playbackDeviceIdentifier: nil,
            onSetVolume: { _ in true }, onSetMuted: { _ in true }, onOpenSettings: {})
            .environment(\.popoverLayout, .compact).frame(width: 280)
        let host = NSHostingView(rootView: content)
        let window = attach(host)
        defer { window.contentView = nil; window.close() }
        settle(host)
        let height = host.fittingSize.height
        // Deliver events only to this offscreen test window. No OS pointer input.
        window.makeKeyAndOrderFront(nil)
        func clickGap() throws {
            let location = host.convert(NSPoint(x: 150, y: 17), to: nil)
            let timestamp = ProcessInfo.processInfo.systemUptime
            let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
                modifierFlags: [], timestamp: timestamp, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location,
                modifierFlags: [], timestamp: timestamp + 0.01, windowNumber: window.windowNumber,
                context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
            NSApp.postEvent(up, atStart: true)
            NSApp.sendEvent(down)
            if let pending = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .default, dequeue: true) {
                NSApp.sendEvent(pending)
            }
            settle(host)
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            settle(host)
        }
        try clickGap()
        XCTAssertGreaterThan(host.fittingSize.height, height + 40)
        try clickGap()
        XCTAssertEqual(host.fittingSize.height, height, accuracy: 1)
    }

    func testBatterySummaryRespectsVisibilityAndChargingState() {
        let battery = BatteryStatus(percentage: 72, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108)
        let full = BatteryStatusRow(battery: battery, showPercentage: true)
        XCTAssertTrue(full.compactValue.contains("72"))
        XCTAssertTrue(full.compactValue.contains("≈"))
        let hidden = BatteryStatusRow(battery: battery, showPercentage: false, showsRemainingTime: false)
        XCTAssertFalse(hidden.compactValue.contains("72"))
        XCTAssertFalse(hidden.compactValue.contains("≈"))
        XCTAssertEqual(hidden.compactValue, battery.powerStateDescription)
        let paused = BatteryStatus(percentage: 80, isCharging: false, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108)
        XCTAssertFalse(BatteryStatusRow(battery: paused, showPercentage: true).compactValue.contains("≈"))
        XCTAssertEqual(BatteryStatusRow(battery: paused, showPercentage: true).compactValue, localized("%d%%", 80))
    }

    @MainActor
    func testRenderBothLayoutsAndExpandedControlsInLightAndDark() async throws {
        let suite = "PopoverLayoutRender.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        configure(defaults)
        let vpn = VPNStatusService(reader: {
            VPNStatus(connections: [VPNConnection(id: "demo", name: "Demo VPN", state: .connected, interfaceName: "utun0")])
        }, monitor: TestVPNChangeMonitor())
        vpn.start()
        defer { vpn.stop() }
        for _ in 0..<50 where vpn.isRefreshing { try await Task.sleep(for: .milliseconds(10)) }
        let store = demoStore(vpn: vpn)
        for dark in [false, true] {
            let root = StatusPopoverView(statusStore: store, onClose: {}).defaultAppStorage(defaults)
            let host = NSHostingView(rootView: root.environment(\.colorScheme, dark ? .dark : .light)
                .background(Color(nsColor: .windowBackgroundColor)))
            let window = attach(host)
            defer { window.contentView = nil; window.close() }
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            for layout in PopoverLayout.allCases {
                defaults.set(layout.rawValue, forKey: PreferenceKeys.popoverLayout)
                settle(host)
                try writePNG(host, name: "\(layout.rawValue)-\(dark ? "dark" : "light")")
            }
            let volume = CompactVolumeSection(volume: store.status.audio.volume,
                hasOutputDevice: true, playbackDeviceIdentifier: nil,
                onSetVolume: { _ in true }, onSetMuted: { _ in true }, onOpenSettings: {}, initiallyExpanded: true)
                .environment(\.popoverLayout, .compact).padding(12).frame(width: 304)
                .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
            let expanded = NSHostingView(rootView: volume)
            let expandedWindow = attach(expanded)
            defer { expandedWindow.contentView = nil; expandedWindow.close() }
            expanded.appearance = host.appearance
            settle(expanded)
            try writePNG(expanded, name: "volume-expanded-\(dark ? "dark" : "light")")
            let settings = NSHostingView(rootView: GeneralSettingsView(onPreviewPopover: {})
                .defaultAppStorage(defaults).frame(width: 560, height: 590)
                .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light))
            let settingsWindow = attach(settings)
            defer { settingsWindow.contentView = nil; settingsWindow.close() }
            settings.appearance = host.appearance
            settle(settings)
            try writePNG(settings, name: "settings-\(dark ? "dark" : "light")")
        }
    }

    @MainActor
    func testCompactLongLabelsStayWithinWidthInAllLanguages() throws {
        for language in AppLanguage.allCases where language != .system {
            let content = VStack(spacing: 0) {
                CompactStatusRow(symbol: "wifi", title: AppLocalization.string("Network", language: language),
                    value: "A-very-long-network-name-that-must-truncate-cleanly")
                CompactStatusRow(symbol: "speaker", title: AppLocalization.string("Audio Output", language: language),
                    value: "Bluetooth Headphones — A Very Long Device Name")
                CompactStatusRow(symbol: "mic", title: AppLocalization.string("Microphone", language: language),
                    value: AppLocalization.string("Unavailable", language: language))
            }.frame(width: 280).background(Color.white).environment(\.colorScheme, .light)
            let host = NSHostingView(rootView: content)
            let window = attach(host)
            defer { window.contentView = nil; window.close() }
            settle(host)
            XCTAssertEqual(host.fittingSize.width, 280, accuracy: 0.1, language.rawValue)
            XCTAssertEqual(host.fittingSize.height, 102, accuracy: 1, language.rawValue)
            try writePNG(host, name: "long-labels-\(language.rawValue)")
        }
    }

    private func configure(_ defaults: UserDefaults) {
        defaults.set("en", forKey: PreferenceKeys.language)
        for key in [PreferenceKeys.showNetwork, PreferenceKeys.showVPN, PreferenceKeys.showVolume,
                    PreferenceKeys.showBattery, PreferenceKeys.showAccessories, PreferenceKeys.showAudioOutput,
                    PreferenceKeys.showBatteryPercentage, PreferenceKeys.showBatteryTime] { defaults.set(true, forKey: key) }
        defaults.set(false, forKey: PreferenceKeys.showMicrophone)
        defaults.set(false, forKey: PreferenceKeys.hideEmptyAccessories)
        defaults.set(MenuSectionOrder.defaultValue, forKey: PreferenceKeys.menuSectionOrder)
    }

    @MainActor
    private func demoStore(vpn: VPNStatusService? = nil) -> SystemStatusStore {
        let store = SystemStatusStore(startServices: false, vpnStatusService: vpn)
        store.applyMarketingCaptureState("hero")
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 72, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108))
        store.applyDebugVolumeState(.fiftyOne)
        return store
    }

    @MainActor
    private func attach<Content: View>(_ host: NSHostingView<Content>) -> NSWindow {
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.contentView = host
        return window
    }

    @MainActor
    private func settle<Content: View>(_ host: NSHostingView<Content>) {
        for _ in 0..<4 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
            host.frame.size = host.fittingSize
            host.layoutSubtreeIfNeeded()
        }
    }

    @MainActor
    private func writePNG<Content: View>(_ host: NSHostingView<Content>, name: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-CompactLayout")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: output.appendingPathComponent(name + ".png"))
    }
}
