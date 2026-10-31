import Foundation

enum DiagnosticOutcome: Equatable, Sendable {
    case passed, failed, notConfirmed
    var title: String {
        switch self {
        case .passed: localized("Passed")
        case .failed: localized("Failed")
        case .notConfirmed: localized("Not confirmed")
        }
    }
}

struct NetworkDiagnosticResult: Equatable, Sendable {
    let dns: DiagnosticOutcome
    let https: DiagnosticOutcome
    let message: String

    static func response(data: Data, response: HTTPURLResponse) -> Self {
        let body = String(decoding: data.prefix(8192), as: UTF8.self).lowercased()
        let success = response.statusCode == 200 && response.url?.host == "www.apple.com"
            && body.contains("<title>success</title>") && body.contains("<body>success</body>")
        return Self(dns: .passed, https: success ? .passed : .failed,
            message: localized(success ? "The Apple test page is reachable. This does not test every app or VPN route."
                : "The test page returned an unexpected response. The network may require sign-in."))
    }

    static func failure(_ error: Error) -> Self {
        let code = (error as? URLError)?.code
        let dnsFailure = code == .cannotFindHost || code == .dnsLookupFailed
        return Self(dns: dnsFailure ? .failed : .notConfirmed, https: .failed,
            message: localized(dnsFailure ? "The test server name could not be resolved."
                : "The HTTPS check failed. Check your connection, network sign-in or VPN."))
    }
}
