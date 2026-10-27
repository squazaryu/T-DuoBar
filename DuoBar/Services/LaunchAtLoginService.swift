import AppKit
import Combine
import ServiceManagement

@MainActor
protocol LoginItemManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() async throws
    func openSettings()
}

@MainActor
private struct SystemLoginItemManager: LoginItemManaging {
    private var canManageInstalledItem: Bool {
        LoginItemInstallation.canManage(bundleURL: Bundle.main.bundleURL,
            isTestHost: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
    }

    // Even reading SMAppService.status associates the calling bundle's URL with
    // the item. A render test must never redirect it to a DerivedData test host.
    var status: SMAppService.Status { canManageInstalledItem ? SMAppService.mainApp.status : .notRegistered }
    func register() throws {
        guard canManageInstalledItem else { throw LoginItemInstallation.Error.notInstalled }
        try SMAppService.mainApp.register()
    }
    func unregister() async throws {
        guard canManageInstalledItem else { throw LoginItemInstallation.Error.notInstalled }
        try await SMAppService.mainApp.unregister()
    }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()
    private static let identityKey = "loginItem.registeredInstallation"

    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?

    private let manager: any LoginItemManaging
    private let defaults: UserDefaults
    private let installationIdentity: () -> String?

    init(manager: (any LoginItemManaging)? = nil, defaults: UserDefaults = .standard,
         installationIdentity: @escaping () -> String? = LaunchAtLoginService.currentInstallationIdentity) {
        self.manager = manager ?? SystemLoginItemManager()
        self.defaults = defaults
        self.installationIdentity = installationIdentity
        refresh()
    }

    func refresh() {
        let status = manager.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        Task { await updateEnabled(enabled) }
    }

    func updateEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        defer { refresh(); isUpdating = false }
        do {
            if enabled {
                // A pending item needs the user's approval, not repeated registration.
                if manager.status == .requiresApproval { manager.openSettings(); return }
                if manager.status != .enabled { try manager.register() }
                rememberInstallationIfEnabled()
            } else {
                if manager.status != .notRegistered { try await manager.unregister() }
                defaults.removeObject(forKey: Self.identityKey)
            }
        } catch {
            let reachedTarget = enabled ? manager.status == .enabled : manager.status == .notRegistered
            if !reachedTarget { errorMessage = error.localizedDescription }
        }
    }

    /// Refresh an already-approved item once after installing a different app
    /// bundle. Never turns an item back on after the user disabled it in macOS.
    func reconcileAfterUpdate() async {
        guard manager.status == .enabled, let identity = installationIdentity(),
              defaults.string(forKey: Self.identityKey) != identity else { refresh(); return }
        await repair()
    }

    func repair() async {
        guard !isUpdating else { return }
        if manager.status == .requiresApproval { refresh(); return }
        isUpdating = true
        errorMessage = nil
        defer { refresh(); isUpdating = false }
        do {
            if manager.status != .notRegistered { try await manager.unregister() }
            try manager.register()
            rememberInstallationIfEnabled()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSystemSettings() { manager.openSettings() }

    private func rememberInstallationIfEnabled() {
        guard manager.status == .enabled, let identity = installationIdentity() else { return }
        defaults.set(identity, forKey: Self.identityKey)
    }

    nonisolated private static func currentInstallationIdentity() -> String? {
        let bundle = Bundle.main
        let path = bundle.bundleURL.standardizedFileURL.path
        // Do not reconcile login items from DerivedData, previews or test hosts.
        guard LoginItemInstallation.canManage(bundleURL: bundle.bundleURL,
                isTestHost: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil),
              let executable = bundle.executableURL,
              let values = try? executable.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modified = values.contentModificationDate, let size = values.fileSize else { return nil }
        return "\(path)|\(modified.timeIntervalSince1970)|\(size)"
    }
}
