import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class DuoCenterOpticalAlignmentTests: XCTestCase {
    private let states: [(String, DuoCenterState)] = [
        ("Wi-Fi", .wifi(.strong)), ("Ethernet", .ethernet), ("Hotspot", .personalHotspot),
        ("Offline", .offline), ("Unavailable", .unavailable), ("Other", .other),
        ("AirPods Pro", .airPodsPro), ("AirPods Max", .airPodsMax), ("AirPods", .airPods),
        ("Headphones", .headphones), ("Audio", .audioDevice),
        ("CPU", .performanceCPU), ("Memory", .performanceMemory), ("Temperature", .performanceThermal)
    ]

    @MainActor
    func testNetworkAudioAndPerformanceSymbolsShareAnOpticalCenter() throws {
        var observations: [[String: Any]] = []
        for backing: CGFloat in [1, 2] {
            for scale in [0.8, 1.0, 1.05, 1.1, 1.15, 1.2] {
                let metrics = DuoGlyphMetrics.standard.scaled(by: scale).fittedToMenuBarHeight()
                for digits in [false, true] {
                    var centers: [String: CGPoint] = [:]
                    for (name, state) in states {
                        let point = try inkCenter(glyph(state, digits: digits, metrics: metrics)
                            .centerContent(reduceMotion: true), backingScale: backing)
                        centers[name] = point
                        observations.append(["state": name, "digits": digits, "scale": scale,
                                             "backing": backing, "x": point.x, "y": point.y])
                    }
                    let wifi = try XCTUnwrap(centers["Wi-Fi"])
                    // Judge placement in backing pixels at the installed size.
                    // A one-pixel tolerance accounts for native SF Symbol hinting;
                    // virtual-canvas fractions overstate precision on 1x displays.
                    let pixelsPerPoint = metrics.overallSize / DuoGlyphMetrics.canvasSize * backing
                    for (name, _) in states {
                        let point = try XCTUnwrap(centers[name])
                        XCTAssertEqual(point.y * pixelsPerPoint, wifi.y * pixelsPerPoint, accuracy: 1.1,
                                       "\(name), digits=\(digits), scale=\(scale), backing=\(backing)")
                        XCTAssertEqual(point.x * pixelsPerPoint, 16 * pixelsPerPoint, accuracy: 1.1,
                                       "\(name), scale=\(scale), backing=\(backing)")
                    }
                }
            }
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-OpticalAlignment")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("centers.json"))
    }

    @MainActor
    func testRenderCurrentLayout() throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-OpticalAlignment")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            let gallery = VStack(spacing: 16) {
                ForEach([false, true], id: \.self) { digits in
                    VStack(spacing: 16) {
                        Text(digits ? "С процентами" : "Без процентов").font(.system(size: 16, weight: .medium))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(96)), count: 7), spacing: 22) {
                            ForEach(self.states.indices, id: \.self) { index in
                                let (name, state) = self.states[index]
                                VStack(spacing: 9) {
                                    self.glyph(state, digits: digits, metrics: .standard.sized(64))
                                    self.glyph(state, digits: digits)
                                        .offset(y: DuoGlyphMetrics.menuBarVerticalOffset)
                                        .frame(width: 30, height: 22).clipped()
                                    Text(name).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if !digits { Divider().padding(.vertical, 4) }
                }
            }.padding(22)
                .background(dark ? Color(red: 0.075, green: 0.08, blue: 0.09) : Color.white)
                .environment(\.colorScheme, dark ? .dark : .light)
            let renderer = ImageRenderer(content: gallery.environment(\.displayScale, 2))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("gallery-\(dark ? "dark" : "light").png"))
        }
    }

    private func glyph(_ state: DuoCenterState, digits: Bool, metrics: DuoGlyphMetrics = .standard) -> DuoGlyphView {
        var status = SystemStatus.unavailable
        status.battery = BatteryStatus(percentage: 80, isCharging: true, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true)
        status.audio.volume = OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true)
        return DuoGlyphView(status: status, metrics: metrics, animationsEnabled: false,
            centerStateOverride: state, batteryColorCodingEnabled: true, showsBatteryPercentage: digits)
    }

    @MainActor
    private func inkCenter<Content: View>(_ content: Content, backingScale: CGFloat) throws -> CGPoint {
        let renderer = ImageRenderer(content: content.frame(width: 32, height: 32)
            .foregroundStyle(.white).environment(\.colorScheme, .dark).environment(\.displayScale, backingScale))
        renderer.scale = 4
        let image = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        var mass: CGFloat = 0, xSum: CGFloat = 0, ySum: CGFloat = 0
        for y in 0..<image.height {
            for x in 0..<image.width {
                let alpha = try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent
                mass += alpha
                xSum += (CGFloat(x) + 0.5) * alpha
                ySum += (CGFloat(y) + 0.5) * alpha
            }
        }
        XCTAssertGreaterThan(mass, 0)
        return CGPoint(x: xSum / mass / 4, y: ySum / mass / 4)
    }
}
