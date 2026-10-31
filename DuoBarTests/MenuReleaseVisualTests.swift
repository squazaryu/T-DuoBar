import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

/// Native production-view fixtures, with isolated preferences and demo data.
@MainActor
final class MenuReleaseVisualTests: XCTestCase {
    func testReleaseVisualMatrix() async throws {
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain) }
        let suite = "MenuReleaseVisual.\(UUID().uuidString)"
        let prefs = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { prefs.removePersistentDomain(forName: suite) }
        prefs.set(false, forKey: PreferenceKeys.animationsEnabled)
        prefs.set(true, forKey: PreferenceKeys.showBatteryTime)
        prefs.set(true, forKey: PreferenceKeys.showBatteryPercentage)
        prefs.set(MenuSectionOrder.defaultValue, forKey: PreferenceKeys.menuSectionOrder)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-ReleaseVisual")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        for language in [AppLanguage.english, .russian, .german, .simplifiedChinese] {
            prefs.set(language.rawValue, forKey: PreferenceKeys.language)
            UserDefaults.standard.setVolatileDomain(arguments.merging([PreferenceKeys.language: language.rawValue]) { _, new in new },
                forName: UserDefaults.argumentDomain)
            let vpn = VPNStatusService(reader: {
                VPNStatus(connections: [VPNConnection(id: "demo", name: "Demo VPN", state: .connected, interfaceName: "utun0")])
            }, monitor: TestVPNChangeMonitor())
            vpn.start()
            defer { vpn.stop() }
            for _ in 0..<50 where vpn.isRefreshing { try await Task.sleep(for: .milliseconds(5)) }
            for dark in [false, true] {
                for layout in PopoverLayout.allCases {
                    for (wide, readable) in [(false, false), (true, false), (false, true), (true, true)] {
                        let enhanced = wide || readable
                        prefs.set(layout.rawValue, forKey: PreferenceKeys.popoverLayout)
                        prefs.set(wide, forKey: PreferenceKeys.widePopover)
                        prefs.set(readable, forKey: PreferenceKeys.readableMenuText)
                        prefs.set(enhanced, forKey: PreferenceKeys.highlightMenuRows)
                        prefs.set(enhanced, forKey: PreferenceKeys.singleExpandedSection)
                        prefs.set(enhanced, forKey: PreferenceKeys.networkDiagnostics)
                        for panel in ["menu", "battery", "network"] {
                            configureVisibility(prefs, panel: panel)
                            let diagnostics = NetworkDiagnosticsService(provider: VisualDiagnostics())
                            let store = makeStore(vpn: vpn, diagnostics: diagnostics)
                            let root = StatusPopoverView(statusStore: store, onClose: {})
                                .defaultAppStorage(prefs).environment(\.colorScheme, dark ? .dark : .light)
                                .background(Color(nsColor: .windowBackgroundColor))
                            let host = NSHostingView(rootView: root)
                            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                            host.frame = NSRect(origin: .zero, size: host.fittingSize)
                            let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
                            window.isReleasedWhenClosed = false
                            window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
                            window.contentView = host
                            defer { window.contentView = nil; window.close() }
                            settle(host)
                            if panel != "menu" {
                                window.makeKeyAndOrderFront(nil)
                                try click(host, window: window, point: NSPoint(x: 90, y: 54))
                                settle(host)
                                if panel == "network", enhanced {
                                    diagnostics.check()
                                    for _ in 0..<20 where diagnostics.isRunning { await Task.yield() }
                                    settle(host)
                                }
                                XCTAssertGreaterThan(host.fittingSize.height, 200, "Expanded panel did not open")
                            }
                            XCTAssertEqual(host.fittingSize.width, wide ? 360 : 304, accuracy: 0.5)
                            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                            host.cacheDisplay(in: host.bounds, to: bitmap)
                            let filename = "\(language.rawValue)-\(dark ? "dark" : "light")-\(layout.rawValue)-\(wide ? "wide" : "normal")-\(readable ? "readable" : "regular")-\(panel).png"
                            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                                .write(to: output.appendingPathComponent(filename))
                        }
                    }
                }
            }
        }
    }

    private func configureVisibility(_ defaults: UserDefaults, panel: String) {
        for (key, name) in [(PreferenceKeys.showNetwork, "network"), (PreferenceKeys.showBattery, "battery"),
                            (PreferenceKeys.showVPN, "vpn"), (PreferenceKeys.showVolume, "volume"),
                            (PreferenceKeys.showAccessories, "accessories"), (PreferenceKeys.showAudioOutput, "audio"),
                            (PreferenceKeys.showMicrophone, "microphone")] {
            defaults.set(panel == "menu" || name == panel, forKey: key)
        }
        defaults.set(false, forKey: PreferenceKeys.hideEmptyAccessories)
    }

    private func makeStore(vpn: VPNStatusService, diagnostics: NetworkDiagnosticsService) -> SystemStatusStore {
        var clock = Date().addingTimeInterval(-6 * 3600)
        let history = BatteryHistoryStore(now: { clock })
        for i in 0...120 {
            defer { clock.addTimeInterval(180) }
            if (71...80).contains(i) { continue }
            let level = i <= 30 ? 84 - i / 3 : i <= 50 ? 74 + i - 30 : i <= 70 ? 94 - (i - 50) / 2 : 80 - (i - 80) / 5
            let plugged = (31...50).contains(i)
            history.record(BatteryStatus(percentage: level, isCharging: plugged, isPluggedIn: plugged,
                isFullyCharged: false, isAvailable: true))
        }
        clock = Date()
        let store = SystemStatusStore(startServices: false, vpnStatusService: vpn,
            batteryHistory: history, networkDiagnostics: diagnostics)
        store.applyMarketingCaptureState("hero")
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 72, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108))
        let speakers = AudioDeviceStatus(uid: "demo-output", name: "MacBook Pro Speakers", transport: .builtIn, isAlive: true)
        let microphone = AudioDeviceStatus(uid: "demo-input", name: "MacBook Pro Microphone", transport: .builtIn, isAlive: true)
        store.applyDebugAudioStatus(AudioStatus(isAvailable: true, defaultOutput: speakers,
            volume: OutputVolumeStatus(level: 0.63, isMuted: false, isSettable: true), connectedBluetoothOutputs: [],
            availableOutputs: [speakers], defaultInput: microphone, availableInputs: [microphone]))
        return store
    }

    private func settle<Content: View>(_ host: NSHostingView<Content>) {
        for _ in 0..<4 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            host.frame.size = host.fittingSize
            host.layoutSubtreeIfNeeded()
        }
    }
    private func click<Content: View>(_ host: NSHostingView<Content>, window: NSWindow, point: NSPoint) throws {
        let location = host.convert(point, to: nil)
        let time = ProcessInfo.processInfo.systemUptime
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [], timestamp: time,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location, modifierFlags: [], timestamp: time + 0.01,
            windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        NSApp.postEvent(up, atStart: true)
        NSApp.sendEvent(down)
        if let event = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
    }
}

private struct VisualDiagnostics: NetworkDiagnosticsProviding {
    func check() async -> NetworkDiagnosticResult {
        .response(data: Data("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>".utf8),
            response: HTTPURLResponse(url: URL(string: "https://www.apple.com/library/test/success.html")!, statusCode: 200,
                httpVersion: nil, headerFields: nil)!)
    }
}
