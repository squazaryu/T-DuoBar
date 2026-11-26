import Combine
import Darwin
import Foundation

@MainActor
final class AccessoryBatteryService: ObservableObject {
    @Published private(set) var accessories: [AccessoryBattery] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var reportTask: Task<[AccessoryBattery]?, Never>?
    private var refreshGeneration: UInt = 0
    private var lastRefresh: TimeInterval?
    private let reportReader: @Sendable () -> [AccessoryBattery]?
    private let now: () -> TimeInterval

    var isPolling: Bool { timer != nil }

    init(reportReader: @escaping @Sendable () -> [AccessoryBattery]? = { AccessoryBatteryService.readConnectedAccessories() },
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.reportReader = reportReader
        self.now = now
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 12
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        refreshGeneration &+= 1
        // Cancelling the waiter alone does not cancel its detached worker.
        reportTask?.cancel()
        reportTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        if isRefreshing { isRefreshing = false }
    }

    func refresh(force: Bool = false) {
        guard isPolling, refreshTask == nil else { return }
        if !force, let lastRefresh, now() - lastRefresh < 60 { return }
        refreshGeneration &+= 1
        let generation = refreshGeneration
        isRefreshing = true
        let reader = reportReader
        let worker = Task.detached(priority: .utility) { () -> [AccessoryBattery]? in
            guard !Task.isCancelled else { return nil }
            return reader()
        }
        reportTask = worker
        refreshTask = Task { [weak self] in
            let result = await worker.value
            // A cancelled reader may finish after the menu has reopened.
            guard let self, !Task.isCancelled, self.refreshGeneration == generation else { return }
            self.lastRefresh = self.now()
            let accessories = result ?? []
            let error = result == nil ? localized("Accessory battery data unavailable") : nil
            if self.accessories != accessories { self.accessories = accessories }
            if self.errorMessage != error { self.errorMessage = error }
            self.isRefreshing = false
            self.reportTask = nil
            self.refreshTask = nil
        }
    }

    nonisolated static func readConnectedAccessories() -> [AccessoryBattery]? {
        guard let connected = readReport(), !Task.isCancelled else { return nil }
        return AccessoryBatteryFallbacks.fillMissingLevels(connected, readHID: AccessoryBatteryFallbacks.readHIDLevels) {
            guard let report = readSystemOutput(executable: URL(fileURLWithPath: "/usr/bin/pmset"),
                arguments: ["-g", "accps"], timeout: 2) else { return [:] }
            return AccessoryBatteryFallbacks.powerLevels(in: report, excluding: AccessoryBatteryFallbacks.systemPowerSourceNames())
        }
    }

    nonisolated static func readReport(
        executable: URL = URL(fileURLWithPath: "/usr/sbin/system_profiler"),
        arguments: [String] = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"],
        timeout: TimeInterval = 10
    ) -> [AccessoryBattery]? {
        guard let data = readSystemOutput(executable: executable, arguments: arguments, timeout: timeout) else { return nil }
        return try? AccessoryBatteryParser.parse(data)
    }

    private nonisolated static func readSystemOutput(executable: URL, arguments: [String], timeout: TimeInterval) -> Data? {
        guard !Task.isCancelled else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("duobar-batteries-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let output = try? FileHandle(forWritingTo: url) else { return nil }
        defer { try? output.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline && !Task.isCancelled {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                let graceDeadline = ProcessInfo.processInfo.systemUptime + 0.3
                while process.isRunning && ProcessInfo.processInfo.systemUptime < graceDeadline {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            process.waitUntilExit()
            guard !Task.isCancelled else { return nil }
            guard process.terminationStatus == 0 else { return nil }
            try output.synchronize()
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber, size.intValue <= 2_097_152 else { return nil }
            return try Data(contentsOf: url)
        } catch { return nil }
    }

    deinit { timer?.invalidate(); reportTask?.cancel(); refreshTask?.cancel() }
}
