import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class CenterGlyphAlignmentTests: XCTestCase {
    private let scenarios: [(String, DuoCenterState)] = [
        ("Wi-Fi", .wifi(.strong)), ("Wi-Fi medium", .wifi(.medium)), ("Wi-Fi weak", .wifi(.weak)),
        ("Wi-Fi off", .wifi(.disabled)), ("Wi-Fi disconnected", .wifi(.disconnected)),
        ("Wi-Fi unknown", .wifi(.unavailable)), ("Ethernet", .ethernet), ("Hotspot", .personalHotspot),
        ("Offline", .offline), ("Other network", .other), ("Unavailable", .unavailable),
        ("AirPods Pro", .airPodsPro), ("AirPods Max", .airPodsMax), ("AirPods", .airPods),
        ("Headphones", .headphones), ("Audio device", .audioDevice),
        ("CPU", .performanceCPU), ("Memory", .performanceMemory), ("Temperature", .performanceThermal)
    ]

    @MainActor
    func testVisibleClassicGlyphBoundsAreCenteredInRingAtSupportedScales() throws {
        for scale in [0.8, 1.0, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            let reference = try bounds(Rectangle().frame(width: 1, height: 1).offset(y: metrics.ringYOffset))
            for (name, state) in scenarios {
                let actual = try bounds(glyph(state, metrics: metrics).centerContent(reduceMotion: false))
                XCTAssertEqual(actual.midX, reference.midX, accuracy: 0.65, "\(name), scale=\(scale)")
                XCTAssertEqual(actual.midY, reference.midY, accuracy: 0.65, "\(name), scale=\(scale)")
            }
        }
    }

    @MainActor
    func testPercentageCenterIsPixelIdenticalToPreviousLayoutForEveryGlyph() throws {
        for scale in [0.8, 1.0, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            for (name, state) in scenarios {
                let expected = try mask(previousCenter(state, metrics: metrics))
                let actual = try mask(glyph(state, metrics: metrics, digits: true).centerContent(reduceMotion: false))
                XCTAssertEqual(actual, expected, "Percentage layout changed: \(name), scale=\(scale)")
            }
        }
    }

    @MainActor
    func testRenderAlignmentGalleries() throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-CenterAlignment")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            let colorScheme: ColorScheme = dark ? .dark : .light
            let background = dark ? Color(red: 0.075, green: 0.08, blue: 0.09) : Color.white
            let gallery = VStack(spacing: 20) {
                Text("Без процентов · центр кольца").font(.system(size: 21, weight: .semibold))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(130)), count: 5), spacing: 24) {
                    ForEach(self.scenarios.indices, id: \.self) { index in
                        let (name, state) = self.scenarios[index]
                        VStack(spacing: 10) {
                            self.glyph(state, metrics: .standard.sized(64))
                            self.glyph(state).frame(width: 30, height: 24)
                            Text(name).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(26).background(background).environment(\.colorScheme, colorScheme)
            try write(gallery, to: output.appendingPathComponent("all-icons-\(dark ? "dark" : "light").png"))

            let selected: [(String, DuoCenterState)] = [("Wi-Fi", .wifi(.strong)), ("Ethernet", .ethernet),
                                                       ("Hotspot", .personalHotspot), ("AirPods Pro", .airPodsPro)]
            let comparison = VStack(spacing: 22) {
                Text("Значки внутри кольца").font(.system(size: 23, weight: .semibold))
                HStack(spacing: 20) {
                    Text("").frame(width: 122)
                    ForEach(selected.indices, id: \.self) { index in
                        Text(selected[index].0).font(.system(size: 13, weight: .medium)).frame(width: 100)
                    }
                }
                HStack(spacing: 20) {
                    Text("Было").frame(width: 122, alignment: .leading)
                    ForEach(selected.indices, id: \.self) { index in
                        self.oldGlyph(selected[index].1).frame(width: 100, height: 70)
                    }
                }
                HStack(spacing: 20) {
                    Text("По центру").frame(width: 122, alignment: .leading)
                    ForEach(selected.indices, id: \.self) { index in
                        self.glyph(selected[index].1, metrics: .standard.sized(64)).frame(width: 100, height: 70)
                    }
                }
                HStack(spacing: 20) {
                    Text("С процентами\nбез изменений").font(.system(size: 12)).frame(width: 122, alignment: .leading)
                    ForEach(selected.indices, id: \.self) { index in
                        self.glyph(selected[index].1, metrics: .standard.sized(64), digits: true).frame(width: 100, height: 70)
                    }
                }
            }.padding(28).background(background).environment(\.colorScheme, colorScheme)
            try write(comparison, to: output.appendingPathComponent("comparison-\(dark ? "dark" : "light").png"))
        }
    }

    private func glyph(_ state: DuoCenterState, metrics: DuoGlyphMetrics = .standard, digits: Bool = false) -> DuoGlyphView {
        var status = SystemStatus.unavailable
        status.battery = BatteryStatus(percentage: 80, isCharging: true, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true)
        status.audio.volume = OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true)
        return DuoGlyphView(status: status, metrics: metrics, animationsEnabled: false,
            centerStateOverride: state, batteryColorCodingEnabled: true, showsBatteryPercentage: digits)
    }

    private func previousCenter(_ state: DuoCenterState, metrics: DuoGlyphMetrics) -> some View {
        DuoCenterTransitionView(targetState: state, size: metrics.wifiSymbolSize,
            ringDiameter: metrics.ringDiameter, ringYOffset: metrics.ringYOffset,
            centerYOffset: metrics.wifiYOffset, pulseScale: 1, animationsEnabled: false, reduceMotion: false)
            .scaleEffect(1.05)
            .offset(y: metrics.wifiYOffset + metrics.ringDiameter * 0.08)
    }

    private func oldGlyph(_ state: DuoCenterState) -> some View {
        let metrics = DuoGlyphMetrics.standard
        return ZStack {
            DuoArcShape(startDegrees: metrics.arcStartDegrees, endDegrees: metrics.arcEndDegrees, progress: 1)
                .stroke(Color.green.opacity(DuoNativeVisualConstants.chargingTrackOpacity),
                    style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round))
                .frame(width: metrics.ringPathDiameter, height: metrics.ringPathDiameter).offset(y: metrics.ringYOffset)
            DuoArcShape(startDegrees: metrics.arcStartDegrees, endDegrees: metrics.arcEndDegrees, progress: 0.8)
                .stroke(Color.green, style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round))
                .frame(width: metrics.ringPathDiameter, height: metrics.ringPathDiameter).offset(y: metrics.ringYOffset)
            previousCenter(state, metrics: metrics)
            DuoDotRow(activeCount: 3, diameter: metrics.dotDiameter, ringDiameter: metrics.ringDiameter,
                rowCenterYOffset: metrics.dotYOffset, animationsEnabled: false, ringCenterYOffset: metrics.ringYOffset)
        }.offset(y: metrics.contentYOffset).frame(width: 32, height: 32)
            .scaleEffect(2).frame(width: 64, height: 64)
    }

    @MainActor
    private func mask<Content: View>(_ content: Content) throws -> [UInt8] {
        let renderer = ImageRenderer(content: content.frame(width: 32, height: 32)
            .foregroundStyle(.white).environment(\.colorScheme, .dark).environment(\.displayScale, 2))
        renderer.scale = 4
        let image = try XCTUnwrap(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: 128 * 128 * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 128, height: 128,
                bitsPerComponent: 8, bytesPerRow: 128 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    @MainActor
    private func bounds<Content: View>(_ content: Content) throws -> CGRect {
        let pixels = try mask(content)
        let indices = pixels.indices.filter { pixels[$0] > 24 }
        XCTAssertFalse(indices.isEmpty)
        let xs = indices.map { $0 % 128 }, ys = indices.map { $0 / 128 }
        return CGRect(x: CGFloat(xs.min() ?? 0) / 4, y: CGFloat(ys.min() ?? 0) / 4,
            width: CGFloat((xs.max() ?? 0) - (xs.min() ?? 0) + 1) / 4,
            height: CGFloat((ys.max() ?? 0) - (ys.min() ?? 0) + 1) / 4)
    }

    @MainActor
    private func write<Content: View>(_ content: Content, to url: URL) throws {
        let renderer = ImageRenderer(content: content.environment(\.displayScale, 2))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: url, options: .atomic)
    }
}
