import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class CompactFooterAlignmentTests: XCTestCase {
    @MainActor
    func testFooterKeepsTextColumnAndUsesASmallerUtilityBar() throws {
        let row = CompactStatusRow(symbol: "gearshape", title: localized("Settings"), value: "")
            .foregroundStyle(.red).frame(width: 280)
        let footer = StatusPopoverFooter(compact: true, onQuit: {}) {
            Button {} label: { StatusPopoverSettingsLabel(compact: true).foregroundStyle(.red) }
                .buttonStyle(.plain)
        }.frame(width: 280)
        let rowInk = try redInk(in: row)
        let footerInk = try redInk(in: footer)
        XCTAssertEqual(footerInk.minX, rowInk.minX, accuracy: 0.5)
        XCTAssertEqual(NSHostingView(rootView: footer).fittingSize.height, 26, accuracy: 0.5)
    }

    func testPluggedInBatteryKeepsItsPercentageReadable() {
        let battery = BatteryStatus(percentage: 90, isCharging: false, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true)
        XCTAssertEqual(CompactBatterySummary.value(battery: battery, showPercentage: true,
            showsRemainingTime: true, fallback: battery.powerStateDescription), localized("%d%%", 90))
        XCTAssertEqual(BatteryStatusRow(battery: battery, showPercentage: true).compactValue,
            localized("%d%%", 90))
    }

    func testBatterySummaryRetainsTimeAndUnavailableStates() {
        let battery = BatteryStatus(percentage: 72, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 108)
        let value = CompactBatterySummary.value(battery: battery, showPercentage: true,
            showsRemainingTime: true, fallback: battery.powerStateDescription)
        XCTAssertTrue(value.contains("72"))
        XCTAssertTrue(value.contains("≈"))
        XCTAssertEqual(CompactBatterySummary.value(battery: battery, showPercentage: false,
            showsRemainingTime: false, fallback: "Power state"), "Power state")
        XCTAssertEqual(CompactBatterySummary.value(battery: .unavailable, showPercentage: true,
            showsRemainingTime: true, fallback: "Unavailable"), "Unavailable")
        for minutes in [0, 25, 60] {
            var charging = battery
            charging.isPluggedIn = true
            charging.isCharging = true
            charging.timeToFullChargeMinutes = minutes
            XCTAssertTrue(CompactBatterySummary.value(battery: charging, showPercentage: false,
                showsRemainingTime: true, fallback: "Power state").hasPrefix("≈"))
        }
    }

    @MainActor
    func testRenderBottomRowsAcrossThemesAndLanguages() async throws {
        let originalArguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { UserDefaults.standard.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }
        let suite = "CompactFooterAlignmentTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(PopoverLayout.compact.rawValue, forKey: PreferenceKeys.popoverLayout)
        for key in [PreferenceKeys.showNetwork, PreferenceKeys.showVPN, PreferenceKeys.showVolume,
                    PreferenceKeys.showBattery, PreferenceKeys.showAudioOutput,
                    PreferenceKeys.showBatteryPercentage, PreferenceKeys.showBatteryTime] {
            defaults.set(true, forKey: key)
        }
        defaults.set(false, forKey: PreferenceKeys.showAccessories)
        defaults.set(false, forKey: PreferenceKeys.showMicrophone)
        let vpn = VPNStatusService(reader: {
            VPNStatus(connections: [VPNConnection(id: "preview", name: "Demo VPN", state: .connected, interfaceName: nil)])
        }, monitor: TestVPNChangeMonitor())
        vpn.start()
        defer { vpn.stop() }
        for _ in 0..<50 where vpn.isRefreshing { try await Task.sleep(for: .milliseconds(10)) }
        let store = SystemStatusStore(startServices: false, vpnStatusService: vpn)
        store.applyDebugNetworkState(.strong)
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 90, isCharging: false, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true))
        let speakers = AudioDeviceStatus(uid: "preview-speakers", name: "MacBook Pro Speakers", transport: .builtIn, isAlive: true)
        store.applyDebugAudioStatus(AudioStatus(isAvailable: true, defaultOutput: speakers,
            volume: OutputVolumeStatus(level: 1, isMuted: false, isSettable: true),
            connectedBluetoothOutputs: [], availableOutputs: [speakers]))
        for language in AppLanguage.allCases where language != .system {
            defaults.set(language.rawValue, forKey: PreferenceKeys.language)
            UserDefaults.standard.setVolatileDomain(
                originalArguments.merging([PreferenceKeys.language: language.rawValue]) { _, new in new },
                forName: UserDefaults.argumentDomain)
            for dark in [false, true] {
                let view = StatusPopoverView(statusStore: store, onClose: {})
                    .defaultAppStorage(defaults).background(Color(nsColor: .windowBackgroundColor))
                let bitmap = try renderBitmap(in: view, dark: dark,
                    name: "compact-\(language.rawValue)-\(dark ? "dark" : "light")")
                XCTAssertEqual(bitmap.pixelsWide, 608)
                XCTAssertGreaterThan(bitmap.pixelsHigh, 440)
            }
        }
    }

    @MainActor
    func testCompactTitleAndDeviceNameShareATextBaseline() throws {
        let bitmap = try renderBitmap(in: CompactStatusRow(symbol: "speaker", title: "xxxx", value: "xxxx")
            .foregroundStyle(.red).frame(width: 280).background(Color.white))
        let scale = CGFloat(bitmap.pixelsWide) / 280
        var titleBottom = -1
        var valueBottom = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if CGFloat(x) < 150 * scale,
                   color.redComponent > color.greenComponent + 0.4,
                   color.redComponent > color.blueComponent + 0.4 {
                    titleBottom = max(titleBottom, y)
                }
                if CGFloat(x) > 200 * scale, CGFloat(x) < 248 * scale,
                   color.redComponent > color.greenComponent + 0.15,
                   color.redComponent > color.blueComponent + 0.15 {
                    valueBottom = max(valueBottom, y)
                }
            }
        }
        XCTAssertGreaterThan(titleBottom, 0)
        XCTAssertGreaterThan(valueBottom, 0)
        XCTAssertEqual(CGFloat(titleBottom) / scale, CGFloat(valueBottom) / scale, accuracy: 0.5,
            "The secondary value must share the title's baseline, not just its bounding-box center")
    }

    @MainActor
    private func redInk<Content: View>(in content: Content) throws -> CGRect {
        let bitmap = try renderBitmap(in: content)
        let scale = CGFloat(bitmap.pixelsWide) / 280
        var bounds = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in Int(35 * scale)..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.25,
                      color.redComponent > color.greenComponent + 0.4,
                      color.redComponent > color.blueComponent + 0.4 else { continue }
                bounds = bounds.union(CGRect(x: CGFloat(x) / scale, y: CGFloat(y) / scale,
                    width: 1 / scale, height: 1 / scale))
            }
        }
        XCTAssertFalse(bounds.isNull, "The actual label must render visible text")
        return bounds
    }

    @MainActor
    private func renderBitmap<Content: View>(in content: Content, dark: Bool = false,
                                           name: String? = nil) throws -> NSBitmapImageRep {
        let host = NSHostingView(rootView: content.environment(\.colorScheme, dark ? .dark : .light))
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        for _ in 0..<4 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            host.frame.size = host.fittingSize
            host.layoutSubtreeIfNeeded()
        }
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-CompactFooter")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let name = name ?? (String(describing: Content.self).contains("Footer") ? "footer" : "row")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: output.appendingPathComponent(name + ".png"))
        return bitmap
    }
}
