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

    func testNextVersionDetailsRenderAndFollowPopoverVisibility() async throws {
        let suite = "MenuNextVersion.\(UUID().uuidString)"
        let prefs = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { prefs.removePersistentDomain(forName: suite) }
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain) }
        prefs.set(false, forKey: PreferenceKeys.animationsEnabled)
        prefs.set(true, forKey: PreferenceKeys.showNetworkTraffic)
        prefs.set(true, forKey: PreferenceKeys.showBatteryHealth)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-NextVersionVisual")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        for (language, layout, dark) in [(AppLanguage.russian, PopoverLayout.standard, false),
                                        (.german, .compact, true)] {
            prefs.set(language.rawValue, forKey: PreferenceKeys.language)
            prefs.set(layout.rawValue, forKey: PreferenceKeys.popoverLayout)
            prefs.set(dark, forKey: PreferenceKeys.readableMenuText)
            let languageOverride = arguments.merging([PreferenceKeys.language: language.rawValue]) { _, new in new }
            UserDefaults.standard.setVolatileDomain(languageOverride, forName: UserDefaults.argumentDomain)
            for panel in ["network", "battery"] {
                configureVisibility(prefs, panel: panel)
                let readings = NextVersionReadings()
                let monitor = NetworkTrafficMonitor { _ in await readings.networkSample() }
                let store = makeStore(vpn: VPNStatusService(monitor: TestVPNChangeMonitor()),
                    diagnostics: NetworkDiagnosticsService(provider: VisualDiagnostics()), networkTraffic: monitor)
                let root = StatusPopoverView(statusStore: store, readBatteryHealth: { await readings.batteryHealth() },
                    onClose: {}).defaultAppStorage(prefs).environment(\.colorScheme, dark ? .dark : .light)
                    .background(Color(nsColor: .windowBackgroundColor))
                let host = NSHostingView(rootView: root)
                host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
                window.contentView = host
                defer { store.setPopoverVisible(false); window.contentView = nil; window.close() }

                window.makeKeyAndOrderFront(nil)
                store.setPopoverVisible(true)
                settle(host)
                let initial = await readings.counts()
                XCTAssertEqual(initial.network, 0)
                XCTAssertEqual(initial.battery, 0)
                let headerY: CGFloat = 54
                let headerTop = host.isFlipped ? headerY : host.bounds.height - headerY
                try click(host, window: window, point: NSPoint(x: 90, y: headerY))
                settle(host)
                if panel == "network" {
                    for _ in 0..<180 where monitor.rates == nil { try await Task.sleep(for: .milliseconds(10)) }
                    XCTAssertEqual(monitor.rates, NetworkTrafficRates(receiveBytesPerSecond: 1_200_000, sendBytesPerSecond: 80_000))
                } else {
                    for _ in 0..<60 {
                        if await readings.counts().battery == 1 { break }
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    let active = await readings.counts()
                    XCTAssertEqual(active.battery, 1)
                    XCTAssertEqual(active.network, 0)
                }
                settle(host)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let image = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try image.write(to: output.appendingPathComponent("\(language.rawValue)-\(layout.rawValue)-\(panel).png"))

                if panel == "network" {
                    if dark { store.setPopoverVisible(false) }
                    else {
                        // Match the real popover's window resize. AppKit discards events
                        // above the original, collapsed bounds of the fixture window.
                        window.setContentSize(host.fittingSize)
                        settle(host)
                        let y = host.isFlipped ? headerTop : host.bounds.height - headerTop
                        try click(host, window: window, point: NSPoint(x: 90, y: y))
                        settle(host)
                    }
                    XCTAssertNil(monitor.rates)
                    let stopped = await readings.counts()
                    try await Task.sleep(for: .milliseconds(1150))
                    let later = await readings.counts()
                    XCTAssertEqual(later.network, stopped.network)
                }
            }
        }
    }

    func testRenderDesktopIndicatorSizes() throws {
        let store = SystemStatusStore(startServices: false, deviceContext: DeviceContext(hasInternalBattery: true))
        store.applyMarketingCaptureState("hero")
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-NextVersionVisual")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            let gallery = HStack(spacing: 14) {
                ForEach(DesktopIndicatorSize.allCases) { size in
                    DesktopIndicatorView(statusStore: store).frame(width: size.edge, height: size.edge)
                }
            }
            .padding(14)
            .background(Color.gray.opacity(0.25))
            .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: gallery)
            renderer.scale = 2
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let name = scheme == .light ? "desktop-light.png" : "desktop-dark.png"
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: output.appendingPathComponent(name))
        }
    }

    func testRenderAccessoryBatteryRowsInBothLayouts() async throws {
        let suite = "MenuAccessoryPreview.\(UUID().uuidString)"
        let prefs = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { prefs.removePersistentDomain(forName: suite) }
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        let language = AppLanguage.russian.rawValue
        UserDefaults.standard.setVolatileDomain(arguments.merging([PreferenceKeys.language: language]) { _, new in new },
            forName: UserDefaults.argumentDomain)
        defer { UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain) }
        prefs.set(false, forKey: PreferenceKeys.animationsEnabled)
        prefs.set(language, forKey: PreferenceKeys.language)
        configureVisibility(prefs, panel: "accessories")

        let service = AccessoryBatteryService(reportReader: {
            [
                AccessoryBattery(id: "headset", name: "Nothing Headphone (1)", levels: ["main": 45],
                    deviceMinorType: "Headset"),
                AccessoryBattery(id: "mouse", name: "Magic Mouse", levels: ["main": 89],
                    deviceMinorType: "Mouse")
            ]
        })
        service.start()
        for _ in 0..<60 where service.isRefreshing { try await Task.sleep(for: .milliseconds(10)) }
        service.stop()
        XCTAssertEqual(service.accessories.compactMap(\.percentage), [45, 89])
        let store = SystemStatusStore(startServices: false, accessoryBatteryService: service)
        store.applyMarketingCaptureState("hero")
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-AccessoryPreview")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        for layout in PopoverLayout.allCases {
            for dark in [false, true] {
                prefs.set(layout.rawValue, forKey: PreferenceKeys.popoverLayout)
                prefs.set(dark, forKey: PreferenceKeys.readableMenuText)
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
                if layout == .compact {
                    let collapsedHeight = host.fittingSize.height
                    window.makeKeyAndOrderFront(nil)
                    try click(host, window: window, point: NSPoint(x: 90, y: 54))
                    settle(host)
                    XCTAssertGreaterThan(host.fittingSize.height, collapsedHeight + 60)
                }
                XCTAssertEqual(host.fittingSize.width, 304, accuracy: 0.5)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let name = "accessories-\(layout.rawValue)-\(dark ? "dark" : "light").png"
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent(name))
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

    private func makeStore(vpn: VPNStatusService, diagnostics: NetworkDiagnosticsService,
                           networkTraffic: NetworkTrafficMonitor? = nil) -> SystemStatusStore {
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
        let store = SystemStatusStore(startServices: false, deviceContext: DeviceContext(hasInternalBattery: true),
            vpnStatusService: vpn, batteryHistory: history, networkDiagnostics: diagnostics, networkTraffic: networkTraffic)
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

private actor NextVersionReadings {
    private let clock = ContinuousClock.now
    private let awakeClock = SuspendingClock.now
    private var networkReads = 0
    private var batteryReads = 0

    func networkSample() -> NetworkTrafficSample {
        networkReads += 1
        return NetworkTrafficSample(interfaceIndex: 1, interfaceChangeTime: 0,
            receivedBytes: UInt64(networkReads) * 1_200_000, sentBytes: UInt64(networkReads) * 80_000,
            time: clock.advanced(by: .seconds(networkReads)), awakeTime: awakeClock.advanced(by: .seconds(networkReads)))
    }

    func batteryHealth() -> BatteryHealthSnapshot {
        batteryReads += 1
        return BatteryHealthSnapshot(maximumCapacityPercentage: 91, cycleCount: 185)
    }

    func counts() -> (network: Int, battery: Int) { (networkReads, batteryReads) }
}

private struct VisualDiagnostics: NetworkDiagnosticsProviding {
    func check() async -> NetworkDiagnosticResult {
        .response(data: Data("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>".utf8),
            response: HTTPURLResponse(url: URL(string: "https://www.apple.com/library/test/success.html")!, statusCode: 200,
                httpVersion: nil, headerFields: nil)!)
    }
}
