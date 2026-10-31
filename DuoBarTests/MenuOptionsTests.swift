import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

@MainActor
final class MenuOptionsTests: XCTestCase {
    func testAllFiveOptionsAreOffByDefaultAndWidthChangesLive() throws {
        let name = "MenuOptions.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for key in [PreferenceKeys.widePopover, PreferenceKeys.highlightMenuRows, PreferenceKeys.readableMenuText,
                    PreferenceKeys.singleExpandedSection, PreferenceKeys.networkDiagnostics] {
            XCTAssertFalse(defaults.bool(forKey: key))
        }
        let store = SystemStatusStore(startServices: false)
        store.applyMarketingCaptureState("hero")
        let host = NSHostingView(rootView: StatusPopoverView(statusStore: store, onClose: {}).defaultAppStorage(defaults))
        let window = attach(host)
        defer { window.contentView = nil; window.close() }
        settle(host)
        XCTAssertEqual(host.fittingSize.width, 304, accuracy: 0.5)
        defaults.set(true, forKey: PreferenceKeys.widePopover)
        settle(host)
        XCTAssertEqual(host.fittingSize.width, 360, accuracy: 0.5)
        defaults.set(true, forKey: PreferenceKeys.readableMenuText)
        settle(host)
        XCTAssertGreaterThan(host.fittingSize.height, 400)
        defaults.set(false, forKey: PreferenceKeys.widePopover)
        settle(host)
        XCTAssertEqual(host.fittingSize.width, 304, accuracy: 0.5)
    }

    func testAccordionDoesNotChangeIndependentSectionsUnlessEnabled() throws {
        for single in [false, true] {
            let name = "MenuAccordion.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(single, forKey: PreferenceKeys.singleExpandedSection)
            defaults.set(false, forKey: PreferenceKeys.animationsEnabled)
            let host = NSHostingView(rootView: AccordionFixture().defaultAppStorage(defaults))
            let window = attach(host)
            window.makeKeyAndOrderFront(nil)
            defer { window.contentView = nil; window.close() }
            settle(host)
            let base = host.fittingSize.height
            try click(host, window: window, point: NSPoint(x: 100, y: 17))
            settle(host)
            let first = host.fittingSize.height
            XCTAssertGreaterThan(first, base + 60)
            try click(host, window: window, point: NSPoint(x: 100, y: host.bounds.height - 17))
            settle(host)
            if single { XCTAssertEqual(host.fittingSize.height, first, accuracy: 1) }
            else { XCTAssertGreaterThan(host.fittingSize.height, first + 60) }
        }
    }

    func testRenderOptionalPresentationAndBatteryHistory() throws {
        let name = "MenuOptions.Render.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("en", forKey: PreferenceKeys.language)
        defaults.set(PopoverLayout.compact.rawValue, forKey: PreferenceKeys.popoverLayout)
        for key in [PreferenceKeys.widePopover, PreferenceKeys.readableMenuText, PreferenceKeys.highlightMenuRows,
                    PreferenceKeys.singleExpandedSection, PreferenceKeys.networkDiagnostics] { defaults.set(true, forKey: key) }
        var clock = Date().addingTimeInterval(-6 * 3600)
        let history = BatteryHistoryStore(now: { clock })
        for i in 0...120 {
            history.record(BatteryStatus(percentage: 96 - i / 4, isCharging: false,
                isPluggedIn: false, isFullyCharged: false, isAvailable: true))
            clock.addTimeInterval(180)
        }
        clock = Date()
        let store = SystemStatusStore(startServices: false, batteryHistory: history)
        store.applyMarketingCaptureState("hero")
        store.applyDebugBatteryStatus(BatteryStatus(percentage: 66, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true))
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-MenuOptions")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            let gallery = HStack(alignment: .top, spacing: 20) {
                StatusPopoverView(statusStore: store, onClose: {})
                    .defaultAppStorage(defaults).fixedSize(horizontal: false, vertical: true)
                    .background(Color(nsColor: .windowBackgroundColor))
                VStack(alignment: .leading, spacing: 14) {
                    BatteryHistorySection(history: history).padding(12).frame(width: 320)
                        .background(Color(nsColor: .windowBackgroundColor))
                    Form { MenuExperienceSettingsView() }.formStyle(.grouped).toggleStyle(.switch)
                        .defaultAppStorage(defaults)
                        .frame(width: 560, height: 360).background(Color(nsColor: .windowBackgroundColor))
                }
            }.padding(20).background(dark ? Color.black : Color.gray.opacity(0.1))
                .environment(\.colorScheme, dark ? .dark : .light)
            let host = NSHostingView(rootView: gallery)
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let window = attach(host)
            defer { window.contentView = nil; window.close() }
            settle(host)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: output.appendingPathComponent("options-\(dark ? "dark" : "light").png"))
        }
    }

    private func attach<Content: View>(_ host: NSHostingView<Content>) -> NSWindow {
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.contentView = host
        return window
    }
    private func settle<Content: View>(_ host: NSHostingView<Content>) {
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
            host.frame.size = host.fittingSize
            host.layoutSubtreeIfNeeded()
        }
    }
    private func click<Content: View>(_ host: NSHostingView<Content>, window: NSWindow, point: NSPoint) throws {
        let location = host.convert(point, to: nil)
        let time = ProcessInfo.processInfo.systemUptime
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [], timestamp: time,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location, modifierFlags: [], timestamp: time + 0.01,
            windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        NSApp.postEvent(up, atStart: true)
        NSApp.sendEvent(down)
        if let event = NSApp.nextEvent(matching: .leftMouseUp, until: .distantPast, inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
    }
}

private struct AccordionFixture: View {
    @State private var active: UUID?
    var body: some View {
        VStack(spacing: 0) {
            StatusDetailSection { Text("First").frame(maxWidth: .infinity, minHeight: 34) }
                content: { Text("First details").frame(height: 70) }
            StatusDetailSection { Text("Second").frame(maxWidth: .infinity, minHeight: 34) }
                content: { Text("Second details").frame(height: 70) }
        }.frame(width: 280).environment(\.expandedMenuSection, $active)
    }
}
