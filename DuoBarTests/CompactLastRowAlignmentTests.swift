import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class CompactLastRowAlignmentTests: XCTestCase {
    @MainActor
    func testLastSectionHasTheSameDividerSpacingAsInteriorSections() throws {
        let suite = "CompactLastRow.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set(PopoverLayout.compact.rawValue, forKey: PreferenceKeys.popoverLayout)
        for key in [PreferenceKeys.showNetwork, PreferenceKeys.showVPN, PreferenceKeys.showVolume,
                    PreferenceKeys.showBattery, PreferenceKeys.showAudioOutput] { preferences.set(true, forKey: key) }
        preferences.set(false, forKey: PreferenceKeys.showAccessories)
        let store = SystemStatusStore(startServices: false)
        store.applyMarketingCaptureState("hero")
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 90, isCharging: false,
            isPluggedIn: true, isFullyCharged: false, isAvailable: true))

        let cases: [(String, Bool, [MenuSection])] = [
            ("audio-last", false, MenuSection.allCases),
            ("microphone-last", true, MenuSection.allCases),
            ("battery-last", true, MenuSection.allCases.filter { $0 != .battery } + [.battery])
        ]
        for (name, microphone, order) in cases {
            preferences.set(microphone, forKey: PreferenceKeys.showMicrophone)
            preferences.set(MenuSectionOrder.encode(order), forKey: PreferenceKeys.menuSectionOrder)
            for dark in [false, true] {
                let view = StatusPopoverView(statusStore: store, onClose: {}).defaultAppStorage(preferences)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .environment(\.colorScheme, dark ? .dark : .light)
                let host = NSHostingView(rootView: view)
                host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
                window.contentView = host
                defer { window.contentView = nil; window.close() }
                for _ in 0..<4 {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.03))
                    host.frame.size = host.fittingSize
                    host.layoutSubtreeIfNeeded()
                }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-LastRow")
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
                guard !dark else { continue }
                let scale = CGFloat(bitmap.pixelsWide) / 304
                var lines: [CGFloat] = []
                for y in Int(40 * scale)..<bitmap.pixelsHigh {
                    let xRange = Int(70 * scale)..<Int(270 * scale)
                    let matches = xRange.filter { x in
                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                        return color.redComponent > 0.6 && color.redComponent < 0.93
                            && abs(color.redComponent - color.greenComponent) < 0.02
                            && abs(color.redComponent - color.blueComponent) < 0.02
                    }.count
                    if Double(matches) / Double(xRange.count) > 0.95 {
                        let pointY = CGFloat(y) / scale
                        if let previous = lines.last, pointY - previous < 2 { continue }
                        lines.append(pointY)
                    }
                }
                XCTAssertEqual(lines.count, microphone ? 6 : 5, "All section boundaries must be visible: \(name), \(lines)")
                guard lines.count >= 3 else { continue }
                let interiorHeight = lines[1] - lines[0]
                let lastHeight = lines[lines.count - 1] - lines[lines.count - 2]
                XCTAssertEqual(lastHeight, interiorHeight, accuracy: 0.5,
                    "Last row must not absorb the footer's outside spacing: \(name), boundaries=\(lines)")
            }
        }
    }
}
