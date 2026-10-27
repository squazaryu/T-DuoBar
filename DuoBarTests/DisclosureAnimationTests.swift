import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class DisclosureAnimationTests: XCTestCase {
    @MainActor
    func testDisclosureInterpolatesHeightAndRespectsMotionPreferences() throws {
        XCTAssertNil(SectionDisclosureAnimation.animation(enabled: true, reduceMotion: true))
        XCTAssertNil(SectionDisclosureAnimation.animation(enabled: false, reduceMotion: false))
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for enabled in [true, false] {
            let name = "DisclosureAnimation.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(enabled, forKey: PreferenceKeys.animationsEnabled)
            let view = StatusDetailSection {
                Text("Section").frame(maxWidth: .infinity, minHeight: 34)
            } content: {
                Text("Details").frame(height: 90)
            }
            .frame(width: 280).defaultAppStorage(defaults)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            defer { window.contentView = nil; window.close() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            let collapsed = host.fittingSize.height
            func clickHeader() throws {
                let location = host.convert(NSPoint(x: 100, y: 17), to: nil)
                let time = ProcessInfo.processInfo.systemUptime
                let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
                    modifierFlags: [], timestamp: time, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location,
                    modifierFlags: [], timestamp: time + 0.01, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
                NSApp.postEvent(up, atStart: true)
                NSApp.sendEvent(down)
                if let event = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .default, dequeue: true) {
                    NSApp.sendEvent(event)
                }
            }
            func sampleHeights(count: Int = 16) -> [CGFloat] {
                (0..<count).map { _ in
                    RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                    let height = host.fittingSize.height
                    window.setContentSize(NSSize(width: 280, height: height))
                    host.frame.size = NSSize(width: 280, height: height)
                    host.layoutSubtreeIfNeeded()
                    return height
                }
            }
            try clickHeader()
            let opening = sampleHeights()
            let expanded = try XCTUnwrap(opening.last)
            XCTAssertGreaterThan(expanded, collapsed + 90)
            try clickHeader()
            let closing = sampleHeights()
            XCTAssertEqual(try XCTUnwrap(closing.last), collapsed, accuracy: 1)
            let intermediate: (CGFloat) -> Bool = { $0 > collapsed + 1 && $0 < expanded - 1 }
            XCTAssertEqual(opening.contains(where: intermediate), enabled && !reduceMotion, "opening: \(opening)")
            XCTAssertEqual(closing.contains(where: intermediate), enabled && !reduceMotion, "closing: \(closing)")
            if enabled && !reduceMotion {
                try clickHeader()
                _ = sampleHeights(count: 3)
                try clickHeader()
                _ = sampleHeights(count: 2)
                try clickHeader()
                XCTAssertEqual(try XCTUnwrap(sampleHeights().last), expanded, accuracy: 1,
                    "Rapid reopening must cancel the old collapse")
                try clickHeader()
                XCTAssertEqual(try XCTUnwrap(sampleHeights().last), collapsed, accuracy: 1)
            }
        }
    }
}
