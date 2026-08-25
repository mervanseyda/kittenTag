import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.string("Sistem Varsayılanı")
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    var languageCode: String {
        switch self {
        case .english: "en"
        case .turkish: "tr"
        case .system:
            L10n.systemLanguageCode(preferredLanguages: Locale.preferredLanguages)
        }
    }

    var locale: Locale { Locale(identifier: languageCode) }
}

enum L10n {
    static var preference: AppLanguagePreference {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.language)
            ?? AppLanguagePreference.system.rawValue
        return AppLanguagePreference(rawValue: rawValue) ?? .system
    }

    static var languageCode: String { preference.languageCode }
    static var locale: Locale { preference.locale }

    static func string(_ key: String) -> String {
        string(key, languageCode: languageCode)
    }

    static func string(_ key: String, languageCode: String) -> String {
        let localizationBundle = bundle(for: languageCode)
        return localizationBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    static func systemLanguageCode(preferredLanguages: [String]) -> String {
        guard let preferred = preferredLanguages.first else { return "en" }
        let normalized = preferred.replacingOccurrences(of: "_", with: "-").lowercased()
        return normalized.hasPrefix("tr") ? "tr" : "en"
    }

    private static func bundle(for languageCode: String) -> Bundle {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        #if SWIFT_PACKAGE
        if let path = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        #endif

        return .main
    }
}
