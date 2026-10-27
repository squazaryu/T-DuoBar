import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class UpstreamFeaturesRenderTests: XCTestCase {
    @MainActor
    func testFittedGlyphInkStaysInsideActualMenuBarViewport() throws {
        for backing: CGFloat in [1, 2] {
            for scale in [0.8, 1.0, 1.05, 1.1, 1.15, 1.2] {
                for digits in [false, true] {
                    for value in [8, 80, 100] {
                        let metrics = DuoGlyphMetrics.standard.scaled(by: scale).fittedToMenuBarHeight()
                        let width = ceil(MenuBarIconSize.statusItemWidth(for: scale))
                        let view = DuoGlyphView(status: status(value), metrics: metrics, animationsEnabled: false,
                            batteryColorCodingEnabled: true, showsBatteryPercentage: digits)
                            .offset(y: metrics.menuBarYOffset)
                            .frame(width: width, height: 22).padding(4)
                            .environment(\.colorScheme, .light).environment(\.displayScale, backing)
                        let renderer = ImageRenderer(content: view)
                        renderer.scale = backing
                        let image = try XCTUnwrap(renderer.cgImage)
                        let bitmap = NSBitmapImageRep(cgImage: image)
                        var clippedInk = false
                        for y in 0..<image.height {
                            for x in 0..<image.width {
                                if CGFloat(y) < 4 * backing || CGFloat(y) >= 26 * backing {
                                    if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { clippedInk = true }
                                }
                            }
                        }
                        XCTAssertFalse(clippedInk, "size=\(scale), digits=\(digits), value=\(value), backing=\(backing)")
                    }
                }
            }
        }
    }

    @MainActor
    func testRenderWiFiAndSizePreview() async throws {
        let preferences = UserDefaults.standard
        let previous = preferences.object(forKey: PreferenceKeys.language)
        preferences.set("en", forKey: PreferenceKeys.language)
        defer {
            if let previous { preferences.set(previous, forKey: PreferenceKeys.language) }
            else { preferences.removeObject(forKey: PreferenceKeys.language) }
        }
        let provider = WiFiArtworkProvider()
        let store = SystemStatusStore(startServices: false, nearbyWiFiProvider: provider)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-UpstreamFeatures")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            store.nearbyWiFiController.setMenuVisible(true)
            await store.nearbyWiFiController.activate()
            store.nearbyWiFiController.setMenuVisible(false)
            let content = VStack(alignment: .leading, spacing: 20) {
                Text("T-DuoBar · Wi-Fi networks").font(.system(size: 20, weight: .semibold, design: .rounded))
                NearbyWiFiSection(store: store, initiallyExpanded: true, onOpenSettings: {})
                    .font(.system(size: 11))
                    .padding(14).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                    .frame(width: 304)
                Text("Icon Size · fitted to menu bar height").font(.system(size: 12, weight: .medium))
                HStack(spacing: 25) {
                    ForEach([1.0, 1.05, 1.1, 1.2], id: \.self) { scale in
                        let metrics = DuoGlyphMetrics.standard.scaled(by: scale).fittedToMenuBarHeight()
                        VStack(spacing: 10) {
                            DuoGlyphView(status: self.status(80), metrics: metrics, animationsEnabled: false,
                                batteryColorCodingEnabled: true, showsBatteryPercentage: true)
                                .offset(y: metrics.menuBarYOffset)
                                .frame(width: 34, height: 22).clipped()
                            Text("\(Int((scale * 100).rounded()))%")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(22)
                .background(dark ? Color(red: 0.08, green: 0.085, blue: 0.10) : Color.white)
                .environment(\.colorScheme, dark ? .dark : .light).environment(\.displayScale, 2)
            let host = NSHostingView(rootView: content)
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("wifi-\(dark ? "dark" : "light").png"))
        }
    }

    private func status(_ value: Int) -> SystemStatus {
        var status = SystemStatus.unavailable
        status.battery = BatteryStatus(percentage: value, isCharging: true, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true)
        status.network = DebugNetworkState.strong.status
        status.audio.volume = OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true)
        return status
    }
}

private struct WiFiArtworkProvider: NearbyWiFiProviding {
    func scan() async throws -> NearbyWiFiScanResult {
        let networks = [
            NearbyWiFiScanCandidate(id: "home", ssid: "Home network", bssid: nil, rssi: -60, channelNumber: 36, security: .personal, isCurrent: true),
            NearbyWiFiScanCandidate(id: "work", ssid: "Office Wi-Fi", bssid: nil, rssi: -48, channelNumber: 6, security: .personal, isCurrent: false),
            NearbyWiFiScanCandidate(id: "guest", ssid: "Guest network", bssid: nil, rssi: -71, channelNumber: 1, security: .open, isCurrent: false),
            NearbyWiFiScanCandidate(id: "enterprise", ssid: "Enterprise network", bssid: nil, rssi: -78, channelNumber: 11, security: .enterprise, isCurrent: false)
        ]
        return NearbyWiFiScanResult(isWiFiPoweredOn: true, networks: networks)
    }
    func associate(networkID: String, password: String?) async throws { }
}
