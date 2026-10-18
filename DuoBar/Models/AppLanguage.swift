import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, english = "en", german = "de", russian = "ru", ukrainian = "uk"
    case simplifiedChinese = "zh-Hans", traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: localized("System language")
        case .english: "English"
        case .german: "Deutsch"
        case .russian: "Русский"
        case .ukrainian: "Українська"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    var locale: Locale { self == .system ? .current : Locale(identifier: rawValue) }
}

enum AppLocalization {
    // Resolve the resource folders once, rather than touching the filesystem
    // for every status label. UserDefaults reads use its thread-safe cache.
    private static let bundles: [AppLanguage: Bundle] = Dictionary(uniqueKeysWithValues:
        AppLanguage.allCases.compactMap { language in
            guard language != .system,
                  let url = Bundle.main.url(forResource: language.rawValue, withExtension: "lproj"),
                  let bundle = Bundle(url: url) else { return nil }
            return (language, bundle)
        })

    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: PreferenceKeys.language) ?? "") ?? .system
    }

    static func string(_ key: String, language: AppLanguage) -> String {
        let bundle = language == .system ? Bundle.main : bundles[language] ?? bundles[.english] ?? .main
        let fallback = bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundle.localizedString(forKey: key, value: fallback, table: nil)
    }
}
