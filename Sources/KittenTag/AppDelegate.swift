import AppKit
import CoreText

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var library: LibraryModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBrandFonts()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let library, !library.dirtyIDs.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.string("Kaydedilmemiş değişiklikler var")
        alert.informativeText = L10n.format("Çıkmadan önce %lld dosyadaki değişiklikleri kaydetmek ister misiniz?", library.dirtyIDs.count)
        alert.addButton(withTitle: L10n.string("Kaydet ve Çık"))
        alert.addButton(withTitle: L10n.string("Kaydetmeden Çık"))
        alert.addButton(withTitle: L10n.string("Vazgeç"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            library.saveChanges { succeeded in
                sender.reply(toApplicationShouldTerminate: succeeded)
            }
            return .terminateLater
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    private func registerBrandFonts() {
        guard let fontsDirectory = Bundle.main.resourceURL?.appendingPathComponent("Fonts") else { return }

        for name in ["Haskoy-Regular", "Haskoy-SemiBold"] {
            let url = fontsDirectory.appendingPathComponent(name).appendingPathExtension("ttf")
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

}
