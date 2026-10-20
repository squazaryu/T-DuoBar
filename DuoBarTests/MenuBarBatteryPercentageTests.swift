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
        XCTAssertTrue(paused.showsBolt)
        battery.isFullyCharged = true
        XCTAssertEqual(DuoBatteryPercentage.resolve(enabled: true, battery: battery, ringMode: .battery)?.value, 100)
        XCTAssertFalse(try XCTUnwrap(DuoBatteryPercentage.resolve(enabled: true,
            battery: self.battery(16), ringMode: .battery)).showsBolt)
    }

    func testGapAdaptsToDigitCountAndBoltWidth() {
        for bolt in [false, true] {
            let small = DuoBatteryPercentage(value: 8, showsBolt: bolt).topGapDegrees
            let medium = DuoBatteryPercentage(value: 80, showsBolt: bolt).topGapDegrees
            let large = DuoBatteryPercentage(value: 100, showsBolt: bolt).topGapDegrees
            XCTAssertLessThan(small, medium)
            XCTAssertLessThanOrEqual(medium, large)
            XCTAssertLessThanOrEqual(large, 156)
            XCTAssertEqual(DuoBatteryPercentage(value: 16, showsBolt: bolt).topGapDegrees, medium)
        }
    }

    func testGreenPowerRingDoesNotDuplicateTheBolt() throws {
        let powered = battery(80, plugged: true)
        let color = try XCTUnwrap(DuoBatteryPercentage.resolve(enabled: true,
            battery: powered, ringMode: .battery, colorCodingEnabled: true))
        let monochrome = try XCTUnwrap(DuoBatteryPercentage.resolve(enabled: true,
            battery: powered, ringMode: .battery, colorCodingEnabled: false))
        XCTAssertFalse(color.showsBolt)
        XCTAssertTrue(monochrome.showsBolt)
        XCTAssertLessThan(color.topGapDegrees, monochrome.topGapDegrees)
    }

    func testBottomDotsFollowTheCircularOuterEdge() {
        for scale in [0.8, 1.0, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            for index in 0..<4 {
                let point = DuoVolumeIndicatorGeometry.circularCenter(index: index,
                    ringDiameter: metrics.ringDiameter, dotDiameter: metrics.dotDiameter,
                    ringCenterY: metrics.ringYOffset)
                XCTAssertEqual(hypot(point.x, point.y - metrics.ringYOffset) + metrics.dotDiameter / 2,
                    metrics.ringDiameter / 2, accuracy: 0.0001)
            }
        }
    }

    @MainActor
    func testEveryReadingHasClearanceFromTheStrokedRing() throws {
        let metrics = DuoGlyphMetrics.standard
        for powered in [false, true] {
            for value in 0...100 {
                let gap = DuoBatteryPercentage(value: value, showsBolt: powered).topGapDegrees
                let ring = DuoPercentageArcShape(startDegrees: metrics.arcStartDegrees,
                    endDegrees: metrics.arcEndDegrees, topGapDegrees: gap, progress: 1)
                    .stroke(.white, style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round))
                    .frame(width: metrics.ringPathDiameter, height: metrics.ringPathDiameter)
                    .offset(y: metrics.ringYOffset)
                    .frame(width: 32, height: 32)
                let ringMask = try alphaMask(ring)
                XCTAssertTrue(ringMask.contains { $0 > 32 }, "Ring must render before checking clearance")
                let label = DuoBatteryPercentageLabel(
                    percentage: DuoBatteryPercentage(value: value, showsBolt: powered), metrics: metrics)
                    .frame(width: 32, height: 32)
                let labelMask = try alphaMask(label)
                XCTAssertTrue(labelMask.contains { $0 > 32 }, "Digits must render before checking clearance")
                // Four pixels per canvas point; require a half-point safety gap.
                let collision = ringMask.indices.first { index in
                    guard ringMask[index] > 32 else { return false }
                    let x = index % 128, y = index / 128
                    for dy in -2...2 {
                        for dx in -2...2 where (0..<128).contains(x + dx) && (0..<128).contains(y + dy) {
                            if labelMask[(y + dy) * 128 + x + dx] > 32 { return true }
                        }
                    }
                    return false
                }
                XCTAssertNil(collision, "Reading \(value), powered=\(powered) touches the ring")
            }
        }
    }

    @MainActor
    private func alphaMask<Content: View>(_ content: Content) throws -> [UInt8] {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light))
        renderer.scale = 4
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(image.width, 128)
        XCTAssertEqual(image.height, 128)
        var pixels = [UInt8](repeating: 0, count: 128 * 128 * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 128, height: 128,
                bitsPerComponent: 8, bytesPerRow: 128 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    func testPercentageProgressExcludesTheLabelGap() {
        let metrics = DuoGlyphMetrics.standard
        let gaps = Set([1, 50, 100].flatMap { value in
            [false, true].map { DuoBatteryPercentage(value: value, showsBolt: $0).topGapDegrees }
        })
        for gap in gaps {
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
                    ForEach([false, true], id: \.self) { colored in
                        HStack(spacing: 20) {
                            ForEach(values, id: \.self) { value in
                                DuoGlyphView(status: self.status(value, plugged: true),
                                    animationsEnabled: false, batteryColorCodingEnabled: colored,
                                    showsBatteryPercentage: true)
                                    .offset(y: DuoGlyphMetrics.menuBarVerticalOffset)
                                    .frame(width: 30, height: 22).clipped()
                            }
                        }
                    }
                    HStack(spacing: 20) {
                        ForEach(values, id: \.self) { value in
                            VStack(spacing: 8) {
                                DuoGlyphView(status: self.status(value), metrics: .standard.sized(88),
                                    animationsEnabled: false, batteryColorCodingEnabled: true,
                                    showsBatteryPercentage: true)
                                DuoGlyphView(status: self.status(value, plugged: true), metrics: .standard.sized(88),
                                    animationsEnabled: false, batteryColorCodingEnabled: true,
                                    showsBatteryPercentage: true)
                            }
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
