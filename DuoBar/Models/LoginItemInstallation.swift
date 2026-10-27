import Foundation

enum LoginItemInstallation {
    static func canManage(bundleURL: URL, isTestHost: Bool, home: String = NSHomeDirectory()) -> Bool {
        guard !isTestHost else { return false }
        let path = bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
    }

    enum Error: LocalizedError {
        case notInstalled
        var errorDescription: String? {
            localized("Install T-DuoBar in Applications before enabling launch at login.")
        }
    }
}
