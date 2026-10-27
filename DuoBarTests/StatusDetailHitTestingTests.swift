import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class StatusDetailHitTestingTests: XCTestCase {
    @MainActor
    func testBatteryHeaderGapTogglesDetailsAndSettingsStaysIndependent() throws {
        var settingsClicks = 0
        let section = StatusDetailSection(settingsTitle: "Battery Settings", onOpenSettings: {
            settingsClicks += 1
        }) {
            BatteryStatusRow(
                battery: BatteryStatus(percentage: 68, isCharging: false, isPluggedIn: false,
                    isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 91),
                showPercentage: true, showsDisclosure: true, drawsBackground: false
            )
        } content: {
            StatusDetailLine(title: "Power source", value: "Battery")
            StatusDetailLine(title: "Adapter power", value: "Unavailable")
        }
        let host = NSHostingView(rootView: section.frame(width: 280))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 280, height: 64),
            styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        func settle() {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            window.setContentSize(host.fittingSize)
            host.layoutSubtreeIfNeeded()
        }

        func click(_ point: NSPoint) throws {
            let location = host.convert(point, to: nil)
            let timestamp = ProcessInfo.processInfo.systemUptime
            let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
                modifierFlags: [], timestamp: timestamp, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location,
                modifierFlags: [], timestamp: timestamp + 0.01, windowNumber: window.windowNumber,
                context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
            // Events stay inside this test application's window; no OS input is injected.
            NSApp.postEvent(up, atStart: true)
            NSApp.sendEvent(down)
            if let pendingUp = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast,
                                               inMode: .default, dequeue: true) {
                NSApp.sendEvent(pendingUp)
            }
            settle()
        }

        settle()
        let collapsedHeight = host.fittingSize.height

        // Positive control: the existing battery icon must open and close details.
        try click(NSPoint(x: 24, y: 32))
        XCTAssertGreaterThan(host.fittingSize.height, collapsedHeight + 20, "Icon click must open details")
        try click(NSPoint(x: 24, y: 32))
        XCTAssertEqual(host.fittingSize.height, collapsedHeight, accuracy: 1)

        // This point is blank, to the right of the text and left of the chevron.
        try click(NSPoint(x: 202, y: 32))
        XCTAssertGreaterThan(host.fittingSize.height, collapsedHeight + 20, "Blank header area must open details")
        try click(NSPoint(x: 202, y: 32))
        XCTAssertEqual(host.fittingSize.height, collapsedHeight, accuracy: 1)

        try click(NSPoint(x: 260, y: 32))
        XCTAssertEqual(settingsClicks, 1, "Settings must receive its own click")
        XCTAssertEqual(host.fittingSize.height, collapsedHeight, accuracy: 1)
    }
}
