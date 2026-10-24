import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class CompactFooterAlignmentTests: XCTestCase {
    @MainActor
    func testFooterUsesTheSameTextColumnAndHeightAsCompactRows() throws {
        let row = CompactStatusRow(symbol: "gearshape", title: localized("Settings"), value: "")
            .foregroundStyle(.red).frame(width: 280)
        let footer = StatusPopoverFooter(compact: true, onQuit: {}) {
            Button {} label: { StatusPopoverSettingsLabel(compact: true).foregroundStyle(.red) }
                .buttonStyle(.plain)
        }.frame(width: 280)
        let rowInk = try redInk(in: row)
        let footerInk = try redInk(in: footer)
        XCTAssertEqual(footerInk.minX, rowInk.minX, accuracy: 0.5)
        XCTAssertEqual(footerInk.midY, rowInk.midY, accuracy: 0.5)
        XCTAssertEqual(NSHostingView(rootView: footer).fittingSize.height, 34, accuracy: 0.5)
    }

    func testPluggedInBatteryKeepsItsPercentageReadable() {
        let battery = BatteryStatus(percentage: 90, isCharging: false, isPluggedIn: true,
            isFullyCharged: false, isAvailable: true)
        XCTAssertEqual(CompactBatterySummary.value(battery: battery, showPercentage: true,
            showsRemainingTime: true, fallback: battery.powerStateDescription), localized("%d%%", 90))
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
    }

    @MainActor
    private func redInk<Content: View>(in content: Content) throws -> CGRect {
        let host = NSHostingView(rootView: content.environment(\.colorScheme, .light))
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-CompactFooter")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let name = String(describing: Content.self).contains("Footer") ? "footer" : "row"
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: output.appendingPathComponent(name + ".png"))
        var bounds = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
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
}
