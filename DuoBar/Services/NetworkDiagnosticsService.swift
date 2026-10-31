import Combine
import Foundation

protocol NetworkDiagnosticsProviding: Sendable {
    func check() async -> NetworkDiagnosticResult
}

struct HTTPSNetworkDiagnosticsProvider: NetworkDiagnosticsProviding {
    func check() async -> NetworkDiagnosticResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: NoDiagnosticRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return .response(data: data, response: http)
        } catch { return .failure(error) }
    }
}

private final class NoDiagnosticRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
final class NetworkDiagnosticsService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var result: NetworkDiagnosticResult?
    private let provider: any NetworkDiagnosticsProviding
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(provider: any NetworkDiagnosticsProviding = HTTPSNetworkDiagnosticsProvider()) { self.provider = provider }

    func check() {
        guard !isRunning else { return }
        isRunning = true
        result = nil
        let generation = UUID()
        self.generation = generation
        let provider = provider
        task = Task { [weak self] in
            let value = await provider.check()
            guard !Task.isCancelled, let self, self.generation == generation else { return }
            self.result = value
            self.isRunning = false
            self.task = nil
        }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        isRunning = false
        result = nil
    }

    deinit { task?.cancel() }
}
