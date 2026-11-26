import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class ExtendedFeaturesTests: XCTestCase {
    private func battery(_ percentage: Int, plugged: Bool = false) -> BatteryStatus {
        BatteryStatus(percentage: percentage, isCharging: plugged, isPluggedIn: plugged,
            isFullyCharged: false, isAvailable: true)
    }

    func testAccessoryParserExcludesDisconnectedCachedReadings() throws {
        let report: [String: Any] = ["SPBluetoothDataType": [[
            "device_connected": [["AirPods Pro": ["device_address": "AA-01", "device_batteryLevelLeft": "82%", "device_batteryLevelRight": "80%", "device_batteryLevelCase": "64%"]]],
            "device_not_connected": [["Old Mouse": ["device_batteryLevelMain": "100%"]]]
        ]]]
        let items = try AccessoryBatteryParser.parse(JSONSerialization.data(withJSONObject: report))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.percentage, 80)
        XCTAssertEqual(items.first?.levels["case"], 64)
        XCTAssertEqual(items.first?.id, "AA-01")
    }

    func testAccessoryPercentageValidationAndUnknownReadings() throws {
        XCTAssertEqual(AccessoryBatteryParser.percentage(" 0% "), 0)
        XCTAssertEqual(AccessoryBatteryParser.percentage(100), 100)
        XCTAssertNil(AccessoryBatteryParser.percentage("101%"))
        XCTAssertNil(AccessoryBatteryParser.percentage(-1))
        XCTAssertNil(AccessoryBatteryParser.percentage(true))
        XCTAssertNil(AccessoryBatteryParser.percentage("not available"))
        let report = ["device_connected": [["Mouse": ["device_batteryLevelMain": "unknown"]]]]
        let item = try AccessoryBatteryParser.parse(JSONSerialization.data(withJSONObject: report)).first
        XCTAssertNotNil(item)
        XCTAssertNil(item?.percentage)
    }

    func testAccessoryParserRejectsInvalidJSON() {
        XCTAssertThrowsError(try AccessoryBatteryParser.parse(Data("invalid".utf8)))
    }

    func testAccessoryFallbacksFillOnlyMissingLevelsForConnectedDevices() throws {
        let report = ["device_connected": [
            ["Office Mouse": ["device_address": "01:23:45:67:89:AB", "device_minorType": "Mouse"]],
            ["Nothing Headphone (1)": ["device_minorType": "Headset"]],
            ["AirPods Pro": ["device_batteryLevelLeft": "0%", "device_batteryLevelCase": "90%"]],
            ["Shared": ["device_address": "01:23:45:67:89:AC", "device_batteryLevelMain": "40%"]],
            ["shared": ["device_address": "01:23:45:67:89:AD"]]
        ]]
        let devices = try AccessoryBatteryParser.parse(JSONSerialization.data(withJSONObject: report))
        let mouseAddress = try XCTUnwrap(AccessoryBatteryParser.normalizedAddress("01-23-45-67-89-ab"))
        let readings = AccessoryBatteryFallbacks.fillMissingLevels(devices, readHID: { requested in
            XCTAssertEqual(requested, [mouseAddress, "0123456789ad"])
            return [mouseAddress: 89]
        }, readPowerSources: {
            ["nothing headphone (1)": 45, "office mouse": 12, "airpods pro": 99, "shared": 30, "disconnected": 73]
        })
        XCTAssertEqual(readings.map(\.id), devices.map(\.id))
        XCTAssertEqual(readings.first { $0.name == "Office Mouse" }?.percentage, 89)
        XCTAssertEqual(readings.first { $0.name == "Office Mouse" }?.symbol, "computermouse")
        XCTAssertEqual(readings.first { $0.name == "Nothing Headphone (1)" }?.percentage, 45)
        XCTAssertEqual(readings.first { $0.name == "AirPods Pro" }?.percentage, 0)
        XCTAssertEqual(readings.first { $0.name == "Shared" }?.percentage, 40)
        XCTAssertNil(readings.first { $0.name == "shared" }?.percentage)
        XCTAssertNil(AccessoryBatteryParser.normalizedAddress("01-23-45-67-89"))
    }

    func testAccessoryPowerSnapshotRejectsMissingAndAmbiguousReadings() {
        let report = """
        Now drawing from 'AC Power'
         -InternalBattery-0 (id=123)\t93%; charged present: true
         -Nothing Headphone (1) (id=124)\t45%; discharging present: true
         -Clavier (id=125)\t0%; discharging present: true
         -Bluetooth Speaker (id=126)\t100%; charged present: true
         -Disconnected (id=127)\t99%; present: false
         -Unknown (id=128)\t101%; discharging present: true
         -Duplicate (id=129)\t10%; discharging present: true
         -duplicate (id=130)\t(no estimate) present: true
        """
        let levels = AccessoryBatteryFallbacks.powerLevels(in: Data(report.utf8), excluding: ["InternalBattery-0"])
        XCTAssertEqual(levels, ["nothing headphone (1)": 45, "clavier": 0, "bluetooth speaker": 100])
    }

    func testAccessoryFallbacksSkipPowerUtilityWhenHIDCompletesReadings() {
        let address = "0123456789ab"
        let mouse = AccessoryBattery(id: address, name: "Custom name", levels: [:],
            bluetoothAddress: address, deviceMinorType: "Mouse")
        let items = AccessoryBatteryFallbacks.fillMissingLevels([mouse], readHID: { _ in [address: 75] }, readPowerSources: {
            XCTFail("No additional report is needed when the address-based read is complete")
            return [:]
        })
        XCTAssertEqual(items.first?.percentage, 75)
    }

    func testAlertCrossingDoesNotRepeatAroundThreshold() {
        var gate = LowBatteryAlertGate()
        XCTAssertFalse(gate.shouldAlert(battery: battery(25), threshold: 20, enabled: true))
        XCTAssertTrue(gate.shouldAlert(battery: battery(20), threshold: 20, enabled: true))
        for percentage in [19, 20, 21, 20, 15] {
            XCTAssertFalse(gate.shouldAlert(battery: battery(percentage), threshold: 20, enabled: true))
        }
        XCTAssertFalse(gate.shouldAlert(battery: battery(40, plugged: true), threshold: 20, enabled: true))
        XCTAssertTrue(gate.shouldAlert(battery: battery(18), threshold: 20, enabled: true))
    }

    func testAlertDoesNotFireAtStartupOrAfterChangingThreshold() {
        var gate = LowBatteryAlertGate()
        XCTAssertFalse(gate.shouldAlert(battery: battery(18), threshold: 20, enabled: true))
        XCTAssertFalse(gate.shouldAlert(battery: battery(15), threshold: 30, enabled: true))
        XCTAssertFalse(gate.shouldAlert(battery: battery(5), threshold: 30, enabled: false))
        XCTAssertEqual(LowBatteryAlertGate.validatedThreshold(-10), 20)
    }

    func testFavoritesUseStableDeviceUIDsAndTolerateDamagedPreferences() {
        let ids: Set<String> = ["device-b", "device-a"]
        XCTAssertEqual(AudioFavorites.decode(AudioFavorites.encode(ids)), ids)
        XCTAssertEqual(AudioFavorites.decode("invalid"), [])
        XCTAssertEqual(AudioFavorites.decode("[\"\",\"device-a\",\"device-a\"]"), ["device-a"])
    }

    @MainActor
    func testLiveInputDiscoveryUsesCoreAudioInputScope() throws {
        let service = AudioOutputService()
        var observed: AudioStatus?
        service.onStatusChange = { observed = $0 }
        service.start()
        let audio = try XCTUnwrap(observed)
        guard let input = audio.defaultInput, input.isAlive else {
            throw XCTSkip("No default live input on this machine")
        }
        XCTAssertTrue(audio.availableInputs.contains(where: { $0.uid == input.uid }))
        XCTAssertFalse(audio.availableInputs.isEmpty)
    }

    @MainActor
    func testInputSelectionInStoreKeepsOutputSelectionUnchanged() {
        let store = SystemStatusStore(startServices: false)
        let output = AudioDeviceStatus(uid: "output", name: "Speakers", transport: .builtIn, isAlive: true)
        let input = AudioDeviceStatus(uid: "input", name: "Microphone", transport: .builtIn, isAlive: true)
        let audio = AudioStatus(isAvailable: true, defaultOutput: output, volume: .unavailable,
            connectedBluetoothOutputs: [], availableOutputs: [output], defaultInput: nil, availableInputs: [input])
        store.applyDebugAudioStatus(audio)
        XCTAssertTrue(store.setDefaultInput(uid: "input"))
        XCTAssertEqual(store.status.audio.defaultInput?.uid, "input")
        XCTAssertEqual(store.status.audio.defaultOutput?.uid, "output")
        XCTAssertFalse(store.setDefaultInput(uid: "missing"))
    }

    @MainActor
    func testExpandedSectionIncludesDetailWithoutClipping() throws {
        let view = StatusDetailSection(initiallyExpanded: true) {
            BatteryStatusRow(battery: battery(55, plugged: true), showPercentage: true, showsDisclosure: true)
        } content: {
            StatusDetailLine(title: "Adapter power", value: "67 W")
            StatusDetailLine(title: "Charge limit", value: nil)
        }.frame(width: 280).padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        // The disclosure measures its natural height on the next SwiftUI pass.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        host.frame.size = host.fittingSize
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(host.bounds.height, 120)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-Expanded-Production.png"))
    }

    @MainActor
    func testRenderExtendedProductionContent() throws {
        let store = SystemStatusStore(startServices: false)
        store.applyDebugBatteryStatus(battery(55))
        store.applyDebugNetworkState(.strong)
        store.applyDebugAudioDeviceState(.builtIn)
        let host = NSHostingView(rootView: StatusPopoverView(statusStore: store, onClose: {}).content
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light))
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.bounds.width, 304, accuracy: 0.5)
        XCTAssertLessThanOrEqual(host.bounds.height, 600)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-Extended-Production.png"))
    }
}
