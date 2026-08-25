import SwiftUI

enum AppPreferences {
    static let appearance = "appearance"
    static let language = "language"
    static let includeSubfolders = "includeSubfolders"
    static let defaultRenamePattern = "defaultRenamePattern"
    static let showSaveSummary = "showSaveSummary"
    static let tableColumnCustomization = "tableColumnCustomization"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            appearance: AppearancePreference.system.rawValue,
            language: AppLanguagePreference.system.rawValue,
            includeSubfolders: true,
            defaultRenamePattern: FilenameTemplate.defaultPattern,
            showSaveSummary: true
        ])
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.string("Sistem")
        case .light: L10n.string("Açık")
        case .dark: L10n.string("Koyu")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
