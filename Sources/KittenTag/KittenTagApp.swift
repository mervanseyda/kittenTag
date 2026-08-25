import SwiftUI

@main
struct KittenTagApp: App {
    @StateObject private var library: LibraryModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppPreferences.appearance) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(AppPreferences.language) private var language = AppLanguagePreference.system.rawValue
    init() {
        AppPreferences.registerDefaults()
        let library = LibraryModel()
        _library = StateObject(wrappedValue: library)
        appDelegate.library = library
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .frame(minWidth: 1_180, minHeight: 720)
                .preferredColorScheme(AppearancePreference(rawValue: appearance)?.colorScheme)
                .environment(\.locale, AppLanguagePreference(rawValue: language)?.locale ?? L10n.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1_280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.string("Dosya veya Klasör Ekle…")) { library.showOpenPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .saveItem) {
                Button(L10n.string("Tüm Değişiklikleri Kaydet")) {
                    NotificationCenter.default.post(name: .saveKittenTagChanges, object: nil)
                }
                    .keyboardShortcut("s")
                    .disabled(library.dirtyIDs.isEmpty || library.isSaving)
                Button(L10n.string("Etiketleri CSV Olarak Dışa Aktar…")) { library.exportCSV() }
                    .disabled(library.tracks.isEmpty)
            }
            CommandGroup(after: .textEditing) {
                Button(L10n.string("Aramaya Git")) {
                    NotificationCenter.default.post(name: .focusKittenTagSearch, object: nil)
                }
                    .keyboardShortcut("f")
                    .disabled(library.tracks.isEmpty)
            }
            CommandGroup(replacing: .appSettings) {
                Button(L10n.string("Ayarlar…")) {
                    NotificationCenter.default.post(name: .showKittenTagSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .help) {
                Button(L10n.string("Klavye Kısayolları…")) {
                    NotificationCenter.default.post(name: .showKittenTagKeyboardGuide, object: nil)
                }
                    .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
}
