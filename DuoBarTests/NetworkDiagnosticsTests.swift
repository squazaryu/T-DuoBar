import AppKit
import XCTest
@testable import DuoBar

final class NetworkDiagnosticsTests: XCTestCase {
    func testHTTPResponsesDoNotMistakePortalOrErrorsForInternetAccess() throws {
        let url = URL(string: "https://www.apple.com/library/test/success.html")!
        let valid = Data("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>".utf8)
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        XCTAssertEqual(NetworkDiagnosticResult.response(data: valid, response: ok).https, .passed)
        XCTAssertEqual(NetworkDiagnosticResult.response(data: Data("Sign in".utf8), response: ok).https, .failed)
        let redirect = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)!
        XCTAssertEqual(NetworkDiagnosticResult.response(data: valid, response: redirect).https, .failed)
        XCTAssertEqual(NetworkDiagnosticResult.failure(URLError(.cannotFindHost)).dns, .failed)
        XCTAssertEqual(NetworkDiagnosticResult.failure(URLError(.timedOut)).dns, .notConfirmed)
        XCTAssertEqual(NetworkDiagnosticResult.failure(URLError(.secureConnectionFailed)).https, .failed)
    }

    @MainActor
    func testNoChecksAtInitializationAndRepeatedClicksCoalesce() async throws {
        let provider = ControlledDiagnostics()
        let service = NetworkDiagnosticsService(provider: provider)
        await Task.yield()
        let initialCount = await provider.count()
        XCTAssertEqual(initialCount, 0)
        for _ in 0..<20 { service.check() }
        for _ in 0..<30 where await provider.count() == 0 { await Task.yield() }
        let startedCount = await provider.count()
        XCTAssertEqual(startedCount, 1)
        XCTAssertTrue(service.isRunning)
        let name = "DiagnosticClose.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: PreferenceKeys.networkDiagnostics)
        let store = SystemStatusStore(startServices: false, networkDiagnostics: service)
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        controller.popoverWillClose(Notification(name: NSPopover.willCloseNotification))
        XCTAssertFalse(service.isRunning)
        await provider.finish(message: "old")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(service.result, "Canceled checks must not revive a hidden result")
        service.check()
        for _ in 0..<30 where await provider.count() < 2 { await Task.yield() }
        await provider.finish(message: "new")
        for _ in 0..<30 where service.isRunning { await Task.yield() }
        XCTAssertEqual(service.result?.message, "new")
    }
}

private actor ControlledDiagnostics: NetworkDiagnosticsProviding {
    private var calls = 0
    private var continuations: [CheckedContinuation<NetworkDiagnosticResult, Never>] = []
    func check() async -> NetworkDiagnosticResult {
        calls += 1
        return await withCheckedContinuation { continuations.append($0) }
    }
    func count() -> Int { calls }
    func finish(message: String) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: NetworkDiagnosticResult(dns: .passed, https: .passed, message: message))
    }
}
