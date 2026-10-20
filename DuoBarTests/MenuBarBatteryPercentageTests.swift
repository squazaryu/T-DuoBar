import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class MenuBarBatteryPercentageTests: XCTestCase {
    func testLabelsRequireAnAvailableBatteryAndBatteryRing() {
        var battery = self.battery(50)
        XCTAssertNil(DuoBatteryPercentage.resolve(enabled: false, battery: battery, ringMode: .battery))
        XCTAssertNil(DuoBatteryPercentage.resolve(enabled: true, battery: battery, ringMode: .adaptive))
        battery.isAvailable = false
        XCTAssertNil(DuoBatteryPercentage.resolve(enabled: true, battery: battery, ringMode: .battery))
        battery.isAvailable = true
        for value: Int? in [nil, -1, 101] {
            battery.percentage = value
            XCTAssertNil(DuoBatteryPercentage.resolve(enabled: true, battery: battery, ringMode: .battery))
        }
    }

    func testChargingPauseKeepsPowerIndicatorAndFullUsesOneHundred() throws {
        var battery = self.battery(80, plugged: true)
        let paused = try XCTUnwrap(DuoBatteryPercentage.resolve(enabled: true, battery: battery, ringMode: .battery))
        XCTAssertEqual(paused.value, 80)
        XCTAssertTrue(paused.showsPower)
        battery.isFullyCharged = true
        XCTAssertEqual(DuoBatteryPercentage.resolve(enabled: true, battery: battery, ringMode: .battery)?.value, 100)
        XCTAssertFalse(try XCTUnwrap(DuoBatteryPercentage.resolve(enabled: true,
            battery: self.battery(16), ringMode: .battery)).showsPower)
    }

    func testPercentageProgressExcludesTheLabelGap() {
        let metrics = DuoGlyphMetrics.standard
        for gap in [96.0, 116.0, 144.0] {
            for progress in [0.0, 0.01, 0.16, 0.5, 0.99, 1.0] {
                let arc = DuoPercentageArcShape(startDegrees: metrics.arcStartDegrees,
                    endDegrees: metrics.arcEndDegrees, topGapDegrees: gap, progress: progress)
                let length = arc.segments.reduce(0) { $0 + $1.upperBound - $1.lowerBound }
                XCTAssertEqual(length, (metrics.arcEndDegrees - metrics.arcStartDegrees - gap) * progress,
                    accuracy: 0.0001)
                for segment in arc.segments {
                    XCTAssertTrue(segment.upperBound <= 270 - gap / 2 + 0.0001
                        || segment.lowerBound >= 270 + gap / 2 - 0.0001)
                }
                if progress == 0.5 { XCTAssertEqual(arc.segments.count, 1) }
            }
        }
    }

    func testSplitArcDoesNotJoinAcrossTheNumber() {
        let metrics = DuoGlyphMetrics.standard
        let arc = DuoPercentageArcShape(startDegrees: metrics.arcStartDegrees,
            endDegrees: metrics.arcEndDegrees, topGapDegrees: 96, progress: 1)
        let stroke = arc.path(in: CGRect(x: 0, y: 0, width: 32, height: 32)).cgPath
            .copy(strokingWithWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
        let gapEndpointY = 16 - cos(48 * Double.pi / 180) * 16
        for x in [12.0, 16.0, 20.0] {
            XCTAssertFalse(stroke.contains(CGPoint(x: x, y: gapEndpointY)),
                "A connecting line would cross the percentage label")
        }
    }

    @MainActor
    func testRenderPercentageAtActualMenuBarSizes() throws {
        let values = [1, 16, 50, 99, 100]
        let gallery = VStack(spacing: 0) {
            ForEach([false, true], id: \.self) { dark in
                VStack(spacing: 16) {
                    ForEach([0.8, 1.0, 1.05], id: \.self) { scale in
                        HStack(spacing: 20) {
                            Text("\(Int((scale * 100).rounded()))% size")
                                .font(.system(size: 11)).frame(width: 70, alignment: .leading)
                            ForEach(values, id: \.self) { value in
                                DuoGlyphView(status: self.status(value),
                                    metrics: DuoGlyphMetrics.standard.scaled(by: scale),
                                    animationsEnabled: false, batteryColorCodingEnabled: true,
                                    showsBatteryPercentage: true)
                                    .offset(y: DuoGlyphMetrics.menuBarVerticalOffset)
                                    .frame(width: 30, height: 22).clipped()
                            }
                        }
                    }
                    HStack(spacing: 20) {
                        ForEach(values, id: \.self) { value in
                            DuoGlyphView(status: self.status(value, plugged: true),
                                animationsEnabled: false, batteryColorCodingEnabled: true,
                                showsBatteryPercentage: true)
                                .offset(y: DuoGlyphMetrics.menuBarVerticalOffset)
                                .frame(width: 30, height: 22).clipped()
                        }
                    }
                    HStack(spacing: 20) {
                        ForEach(values, id: \.self) { value in
                            DuoGlyphView(status: self.status(value), metrics: .standard.sized(88),
                                animationsEnabled: false, batteryColorCodingEnabled: true,
                                showsBatteryPercentage: true)
                        }
                    }
                }
                .padding(20)
                .foregroundStyle(dark ? Color.white : Color.black)
                .background(dark ? Color.black : Color.white)
                .environment(\.colorScheme, dark ? .dark : .light)
            }
        }
        let host = NSHostingView(rootView: gallery)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-Percentage-Comparison.png"))
        XCTAssertGreaterThan(png.count, 1_000)
    }

    private func battery(_ value: Int, plugged: Bool = false) -> BatteryStatus {
        BatteryStatus(percentage: value, isCharging: false, isPluggedIn: plugged,
            isFullyCharged: value == 100, isAvailable: true)
    }

    private func status(_ value: Int, plugged: Bool = false) -> SystemStatus {
        SystemStatus(battery: battery(value, plugged: plugged),
            network: NetworkStatus(isAvailable: true, isConnected: true, transport: .wifi,
                interfaceName: "en0", isWiFiPoweredOn: true, ssid: "Test", rssi: -42),
            audio: AudioStatus(isAvailable: true, defaultOutput: nil,
                volume: OutputVolumeStatus(level: 1, isMuted: false, isSettable: true),
                connectedBluetoothOutputs: []), bluetooth: .unavailable)
    }
}
