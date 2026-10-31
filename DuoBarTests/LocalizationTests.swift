import Foundation
import XCTest
@testable import DuoBar

final class LocalizationTests: XCTestCase {
    private let requiredKeys = [
        "Menu options",
        "Wider pop-up",
        "Highlight menu rows",
        "Larger, higher-contrast menu text",
        "Expand one section at a time",
        "Show network diagnostics",
        "Diagnostics run only when you press Check connection. No background checks.",
        "Check connection",
        "Checks www.apple.com over HTTPS. DNS errors are reported separately. Runs only on request.",
        "Connect to a network before checking.",
        "Name resolution",
        "HTTPS reachability",
        "Passed",
        "Failed",
        "Not confirmed",
        "The Apple test page is reachable. This does not test every app or VPN route.",
        "The test page returned an unexpected response. The network may require sign-in.",
        "The test server name could not be resolved.",
        "The HTTPS check failed. Check your connection, network sign-in or VPN.",
        "Battery history · 6 hours",
        "History appears as battery readings are collected.",
        "Used in the last hour: %d%%",
        "Stored locally for 24 hours. Gaps and charging sessions are shown separately.",
        "Time",
        "Charge",

        "Repair login item",
        "Login Items Settings…",
        "Install T-DuoBar in Applications before enabling launch at login.",
        "No devices",
        "Menu layout",
        "Standard",
        "Compact",
        "Compact rows show a summary. Click a row for details and controls.",
        "Accessories",
        "Devices: %d",

        "Battery percentage in menu bar",
        "Nearby Networks",
        "Scanning…",
        "Joining…",
        "No nearby networks found. Check Location Services or open Wi-Fi Settings.",
        "Wi-Fi password",
        "Cancel",
        "Join",
        "Refresh",
        "Wi-Fi Settings…",
        "Join Network",
        "Wi-Fi is Off",
        "Wi-Fi unavailable",
        "Unable to Join",
        "Enter a valid Wi-Fi password.",
        "Open Wi-Fi Settings",
        "Unable to Scan",
        "For clearer digits, use Icon Size of 100% or larger.",
        "macOS limits icon height. Large sizes are fitted to the menu bar.",

        "For clearer digits, set Icon Size to 100% or 105%.",
        "Classic",
        "Preview menu",
        "Liquid Glass",
        "Pop-up appearance",
        "Background transparency",
        "Liquid Glass requires macOS 26 or later.",
        "Reduce Transparency is enabled in macOS. The menu uses an opaque background.",
        "Text and controls stay opaque. macOS manages the glass effect.",
        "VPN",
        "Connecting…",
        "Disconnecting…",
        "Disconnected",
        "Not configured",
        "Unnamed VPN",
        "VPN status unavailable",
        "No macOS VPN profiles found",
        "Open VPN Settings",
        "Checking…",
        "Reading VPN status…",
        "macOS could not read VPN status.",
        "Interface",
        "Only VPN connections reported by macOS are shown.",
        "Language",
        "System language",
        "Hide empty accessory section",
        "Connected devices appear automatically. Read errors remain visible.",
        "Adjust volume by scrolling over the icon",
        "Scroll up to raise volume, down to lower it. Trackpad momentum is ignored.",
        "Battery connected, not charging",
        "Battery time estimate unavailable",
        "Less than one minute",
        "%d min",
        "%d h %d min",
        "Until full charge: ≈%@",
        "Until empty: ≈%@",
        "Show details",
        "Expanded",
        "Collapsed",
        "Unavailable",
        "Accessory batteries",
        "Reading accessories…",
        "No connected accessories",
        "Accessory battery data unavailable",
        "Battery reading unavailable",
        "Left",
        "Right",
        "Case",
        "No audio devices",
        "Unable to select audio device",
        "Favorite audio device",
        "Microphone",
        "Menu sections",
        "Drag the handles to reorder sections. Right-click a row for move actions.",
        "Drag to reorder",
        "Reset order",
        "Move up",
        "Move down",
        "Battery: %d%%",
        "Battery data unavailable",
        "No internal battery",
        "Allow location access to show the Wi-Fi name.",
        "Location access is off. Check Location Services and access for T-DuoBar.",
        "Location access is restricted on this Mac. Check the privacy settings.",
        "macOS has not provided the Wi-Fi name. Check the connection in Wi-Fi Settings.",
        "Allow access…",
        "Location Settings…",
        "Bluetooth Settings…",
        "No network interface is available. Check your connection in System Settings.",
        "macOS has not reported the adapter power.",
        "macOS has not provided a time estimate yet. Check again after the power source or workload settles.",
        "The charge limit is unavailable to T-DuoBar. Check charging options in Battery Settings.",
        "Could not read the battery status. Check Battery Settings.",
        "This Mac has no internal battery.",
        "Could not read accessory data. Check the Bluetooth connection and try again.",
        "Try again",
        "macOS has not reported a battery level.",
        "No audio devices found. Check their connection in Sound Settings.",
        "Show battery time",
        "Notifications",
        "Low battery",
        "Battery threshold",
        "Notification sound",
        "One alert when battery crosses the threshold.",
        "Notification Settings…",
        "Allow DuoBar notifications in System Settings.",
        "Unable to enable notifications",
        "Unable to deliver battery notification",
        "Estimated %d minutes of battery remaining",
        "Power source",
        "Adapter power",
        "Charge limit",
        "%d W",
        "Signal",
        "Band",
        "Channel",
        "IP address",
        "Copy IP address",
        "Application updates",
        "Installed version",
        "Available version",
        "%@ (build %d)",
        "Installed: %@. Update available: %@.",
        "DuoBar %@ is up to date",
        "No updates are available.",
        "Check for updates weekly",
        "Checks run while DuoBar is open, including after launch or waking your Mac.",
        "Check for updates now",
        "You have the latest version",
        "Installed DuoBar version: %@",
        "Unable to check for updates",
        "Check your internet connection and try again.",
        "OK",
        "Update available: %@",
        "Update check failed. Will retry later.",
        "Terminal will update DuoBar with Homebrew and restart it. No other packages are upgraded.",
        "Install with Homebrew",
        "Later",
        "Unable to start Homebrew. Use the update command below.",
        "DuoBar update available",
        "Version %@ is ready to install with Homebrew.",
        "Last checked",
        "Release notes",
        "Copy update command",
        "Allow update notifications",
        "Network",
        "Personal Hotspot",
        "Wi-Fi",
        "Wi-Fi power",
        "Wi-Fi control unavailable",
        "Unable to change Wi-Fi power",
        "Off",
        "Volume",
        "Battery",
        "Audio Output",
        "Audio Device",
        "Settings",
        "Settings…",
        "Check for updates…",
        "Quit T-DuoBar",
        "Appearance",
        "Behavior",
        "Updates",
        "Notification access",
        "Manual update command",
        "Developer diagnostics",
        "About T-DuoBar",
        "T-DuoBar Settings",
        "Battery, network and audio at a glance.",
        "Community fork by squazaryu.",
        "Based on DuoBar by Mike Li (Mikeli7666).",
        "Project",
        "Original DuoBar",
        "MIT License",
        "Quit DuoBar",
        "Icon Size",
        "Open on Hover",
        "Open DuoBar when the pointer moves over the menu bar icon.",
        "Launch DuoBar at login",
        "Controlled by device",
        "Charging",
        "Fully charged",
        "Offline",
        "Automatic",
        "Prefer CPU",
        "Prefer Memory",
        "Prefer Thermal",
        "%d%%",
        "volume %d percent",
        "battery %d percent",
        "Sound Settings…",
        "Select audio output",
        "Open Wi-Fi Settings",
        "Open Network Settings",
        "Open Battery Settings",
        "No output devices"
    ]

    func testAllSupportedLocalizationResourcesExist() {
        for language in AppLanguage.allCases.filter({ $0 != .system }).map(\.rawValue) {
            XCTAssertNotNil(localizationBundle(for: language), "Missing \(language).lproj")
        }
    }

    func testRequiredProductionKeysArePresentAndNonEmptyInEverySupportedLanguage() {
        for language in AppLanguage.allCases.filter({ $0 != .system }).map(\.rawValue) {
            guard let bundle = localizationBundle(for: language) else {
                return XCTFail("Missing \(language).lproj")
            }
            guard let strings = localizationStrings(in: bundle) else {
                return XCTFail("Missing Localizable.strings in \(language)")
            }

            for key in requiredKeys {
                guard let value = strings[key] as? String else {
                    return XCTFail("Missing \(key) in \(language)")
                }
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(key) in \(language)")
            }
        }
    }

    func testFormatPlaceholdersRemainCompatible() {
        for language in AppLanguage.allCases.filter({ $0 != .system }).map(\.rawValue) {
            guard let bundle = localizationBundle(for: language) else {
                return XCTFail("Missing \(language).lproj")
            }

            XCTAssertTrue(NSLocalizedString("%d%%", bundle: bundle, comment: "").contains("%d"))
            XCTAssertTrue(NSLocalizedString("volume %d percent", bundle: bundle, comment: "").contains("%d"))
            XCTAssertTrue(NSLocalizedString("battery %d percent", bundle: bundle, comment: "").contains("%d"))
        }
    }

    func testGermanCoversEveryEnglishKeyAndPreservesFormatArguments() throws {
        let englishBundle = try XCTUnwrap(localizationBundle(for: "en"))
        let germanBundle = try XCTUnwrap(localizationBundle(for: "de"))
        let english = try XCTUnwrap(localizationStrings(in: englishBundle) as? [String: String])
        let german = try XCTUnwrap(localizationStrings(in: germanBundle) as? [String: String])
        XCTAssertEqual(Set(german.keys), Set(english.keys))
        let format = try NSRegularExpression(pattern: #"%(?:\d+\$)?[@diuf%]"#)
        func arguments(in value: String) -> [String] {
            format.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                (value as NSString).substring(with: $0.range)
            }
        }
        for (key, source) in english {
            let translated = try XCTUnwrap(german[key], "Missing German key: \(key)")
            XCTAssertFalse(translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
            XCTAssertEqual(arguments(in: source), arguments(in: translated), key)
        }
    }

    func testGermanRegionalSystemLanguagesResolveToGermanResources() {
        for region in ["de-DE", "de-AT", "de-CH"] {
            XCTAssertEqual(Bundle.preferredLocalizations(from: Bundle.main.localizations,
                forPreferences: [region]).first, "de")
        }
        XCTAssertEqual(AppLanguage.german.name, "Deutsch")
        XCTAssertEqual(AppLanguage.german.locale.language.languageCode?.identifier, "de")
    }

    func testPreferencePersistenceIdentifiersRemainStable() {
        XCTAssertEqual(PerformancePreference.automatic.rawValue, "Automatic")
        XCTAssertEqual(PerformancePreference.cpu.rawValue, "Prefer CPU")
        XCTAssertEqual(PerformancePreference.memory.rawValue, "Prefer Memory")
        XCTAssertEqual(PerformancePreference.thermal.rawValue, "Prefer Thermal")
    }

    func testUnsupportedLocaleFallsBackToEnglishBundle() {
        guard let englishBundle = localizationBundle(for: "en") else {
            return XCTFail("Missing English localization bundle")
        }
        XCTAssertEqual(
            NSLocalizedString("Settings", bundle: englishBundle, comment: ""),
            "Settings"
        )
    }

    private func localizationBundle(for language: String) -> Bundle? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        return Bundle(url: resourceURL.appending(path: "\(language).lproj"))
    }

    private func localizationStrings(in bundle: Bundle) -> NSDictionary? {
        guard let url = bundle.url(forResource: "Localizable", withExtension: "strings") else {
            return nil
        }
        return NSDictionary(contentsOf: url)
    }
}
