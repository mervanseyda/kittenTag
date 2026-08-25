import XCTest
@testable import KittenTag

final class LocalizationTests: XCTestCase {
    func testSystemLanguageUsesTurkishOnlyWhenPrimaryLanguageIsTurkish() {
        XCTAssertEqual(L10n.systemLanguageCode(preferredLanguages: ["tr-TR", "en-US"]), "tr")
        XCTAssertEqual(L10n.systemLanguageCode(preferredLanguages: ["en-US", "tr-TR"]), "en")
        XCTAssertEqual(L10n.systemLanguageCode(preferredLanguages: ["de-DE"]), "en")
        XCTAssertEqual(L10n.systemLanguageCode(preferredLanguages: []), "en")
    }

    func testEnglishAndTurkishResourcesCanBeResolvedDirectly() {
        XCTAssertEqual(L10n.string("Ayarlar", languageCode: "en"), "Settings")
        XCTAssertEqual(L10n.string("Kaydet", languageCode: "en"), "Save")
        XCTAssertEqual(L10n.string("Klavye Kısayolları", languageCode: "en"), "Keyboard Shortcuts")
        XCTAssertEqual(L10n.string("Değişiklikleri Kaydet", languageCode: "en"), "Save Changes")
        XCTAssertEqual(L10n.string("Ayarlar", languageCode: "tr"), "Ayarlar")
        XCTAssertEqual(L10n.string("Kaydet", languageCode: "tr"), "Kaydet")
        XCTAssertEqual(L10n.string("Klavye Kısayolları", languageCode: "tr"), "Klavye Kısayolları")
        XCTAssertEqual(L10n.string("Değişiklikleri Kaydet", languageCode: "tr"), "Değişiklikleri Kaydet")
    }
}
