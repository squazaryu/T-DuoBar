import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class CompactFooterAlignmentTests: XCTestCase {
    @MainActor
    func testFooterUsesTheSameTextColumnAndHeightAsCompactRows() throws {
        let row = CompactStatusRow(symbol: "gearshape", title: "Settings", value: "")
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
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        var bounds = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.25, color.redComponent > 0.7,
                      color.greenComponent < 0.3, color.blueComponent < 0.3 else { continue }
                bounds = bounds.union(CGRect(x: CGFloat(x) / 2, y: CGFloat(y) / 2, width: 0.5, height: 0.5))
            }
        }
        XCTAssertFalse(bounds.isNull, "The actual label must render visible text")
        return bounds
    }
}
