import ServiceManagement
import XCTest
@testable import DuoBar

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    func testTestHostsAndTemporaryCopiesCannotRedirectTheInstalledLoginItem() {
        XCTAssertFalse(LoginItemInstallation.canManage(bundleURL: URL(fileURLWithPath: "/tmp/DerivedData/DuoBar.app"), isTestHost: false))
        XCTAssertFalse(LoginItemInstallation.canManage(bundleURL: URL(fileURLWithPath: "/Applications/DuoBar.app"), isTestHost: true))
        XCTAssertFalse(LoginItemInstallation.canManage(bundleURL: URL(fileURLWithPath: "/ApplicationsFake/DuoBar.app"), isTestHost: false))
        XCTAssertTrue(LoginItemInstallation.canManage(bundleURL: URL(fileURLWithPath: "/Applications/DuoBar.app"), isTestHost: false))
        XCTAssertTrue(LoginItemInstallation.canManage(bundleURL: URL(fileURLWithPath: "/Users/example/Applications/DuoBar.app"), isTestHost: false, home: "/Users/example"))
    }

    func testApprovalIsNotDisplayedAsEnabledAndExternalChangesRefresh() {
        let backend = FakeLoginItemManager(status: .requiresApproval)
        let service = LaunchAtLoginService(manager: backend)
        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(service.requiresApproval)
        backend.status = .enabled
        service.refresh()
        XCTAssertTrue(service.isEnabled)
        XCTAssertFalse(service.requiresApproval)
        backend.status = .notRegistered
        service.refresh()
        XCTAssertFalse(service.isEnabled)
    }

    func testRegistrationAndDisablingAreIdempotent() async throws {
        let (service, backend, defaults, name) = makeService(status: .notRegistered)
        defer { defaults.removePersistentDomain(forName: name) }
        await service.updateEnabled(true)
        await service.updateEnabled(true)
        XCTAssertEqual(backend.calls, ["register"])
        XCTAssertTrue(service.isEnabled)
        await service.updateEnabled(false)
        await service.updateEnabled(false)
        XCTAssertEqual(backend.calls, ["register", "unregister"])
        XCTAssertFalse(service.isEnabled)
        XCTAssertNil(service.errorMessage)
    }

    func testChangedInstallationRepairsOnceAndWaitsForUnregister() async {
        let (service, backend, defaults, name) = makeService(status: .enabled)
        defer { defaults.removePersistentDomain(forName: name) }
        backend.delayUnregister = true
        let repair = Task { await service.reconcileAfterUpdate() }
        for _ in 0..<50 where backend.unregistrationContinuation == nil { await Task.yield() }
        XCTAssertTrue(service.isUpdating)
        XCTAssertEqual(backend.calls, ["unregister"])
        backend.completeUnregister()
        await repair.value
        XCTAssertEqual(backend.calls, ["unregister", "register"])
        XCTAssertTrue(service.isEnabled)
        await service.reconcileAfterUpdate()
        XCTAssertEqual(backend.calls.count, 2, "Do not re-register every app launch")
        let next = LaunchAtLoginService(manager: backend, defaults: defaults, installationIdentity: { "new-build" })
        backend.delayUnregister = false
        await next.reconcileAfterUpdate()
        XCTAssertEqual(backend.calls, ["unregister", "register", "unregister", "register"])
    }

    func testAutomaticRepairNeverOverridesDisabledOrPendingItems() async {
        for status in [SMAppService.Status.notRegistered, .requiresApproval, .notFound] {
            let (service, backend, defaults, name) = makeService(status: status)
            defer { defaults.removePersistentDomain(forName: name) }
            await service.reconcileAfterUpdate()
            XCTAssertTrue(backend.calls.isEmpty)
            XCTAssertFalse(service.isEnabled)
        }
    }

    func testPendingEnableOpensSettingsWithoutRegisteringAgain() async {
        let (service, backend, defaults, name) = makeService(status: .requiresApproval)
        defer { defaults.removePersistentDomain(forName: name) }
        await service.updateEnabled(true)
        XCTAssertEqual(backend.calls, ["settings"])
        XCTAssertTrue(service.requiresApproval)
        XCTAssertFalse(service.isEnabled)
    }

    func testFailureDoesNotPretendLoginIsEnabledAndCanBeRetried() async {
        let (service, backend, defaults, name) = makeService(status: .notRegistered)
        defer { defaults.removePersistentDomain(forName: name) }
        backend.registrationError = NSError(domain: "TestLogin", code: 1)
        await service.updateEnabled(true)
        XCTAssertFalse(service.isEnabled)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertFalse(service.isUpdating)
        backend.registrationError = nil
        await service.updateEnabled(true)
        XCTAssertTrue(service.isEnabled)
        XCTAssertNil(service.errorMessage)
    }

    func testFailedUnregisterDoesNotRegisterOverExistingItem() async {
        let (service, backend, defaults, name) = makeService(status: .enabled)
        defer { defaults.removePersistentDomain(forName: name) }
        backend.unregistrationError = NSError(domain: "TestLogin", code: 2)
        await service.repair()
        XCTAssertEqual(backend.calls, ["unregister"])
        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.isEnabled)
        XCTAssertFalse(service.isUpdating)
    }

    private func makeService(status: SMAppService.Status) -> (LaunchAtLoginService, FakeLoginItemManager, UserDefaults, String) {
        let name = "LaunchAtLoginTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let backend = FakeLoginItemManager(status: status)
        return (LaunchAtLoginService(manager: backend, defaults: defaults, installationIdentity: { "build-A" }), backend, defaults, name)
    }
}

@MainActor
private final class FakeLoginItemManager: LoginItemManaging {
    var status: SMAppService.Status
    var calls: [String] = []
    var registrationError: Error?
    var unregistrationError: Error?
    var delayUnregister = false
    var unregistrationContinuation: CheckedContinuation<Void, Never>?
    init(status: SMAppService.Status) { self.status = status }
    func register() throws {
        calls.append("register")
        if let registrationError { throw registrationError }
        status = .enabled
    }
    func unregister() async throws {
        calls.append("unregister")
        if let unregistrationError { throw unregistrationError }
        if delayUnregister { await withCheckedContinuation { unregistrationContinuation = $0 } }
        status = .notRegistered
    }
    func completeUnregister() { unregistrationContinuation?.resume(); unregistrationContinuation = nil }
    func openSettings() { calls.append("settings") }
}
