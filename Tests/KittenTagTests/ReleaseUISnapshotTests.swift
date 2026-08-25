import AppKit
import AVFoundation
import SwiftUI
import XCTest
@testable import KittenTag

/// Opt-in visual release audit. It renders kittenTag off-screen, so it does
/// not capture the desktop and never needs the user's music library.
final class ReleaseUISnapshotTests: XCTestCase {
    @MainActor
    func testRenderReleaseUISnapshots() async throws {
        guard ProcessInfo.processInfo.environment["KITTENTAG_UI_AUDIT"] == "1" else {
            throw XCTSkip("Set KITTENTAG_UI_AUDIT=1 to render release UI snapshots.")
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-ui-audit", isDirectory: true)
        try? FileManager.default.removeItem(at: output)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        try render(
            library: LibraryModel(),
            language: .english,
            appearance: .aqua,
            to: output.appendingPathComponent("welcome-en-light.png")
        )
        try render(
            library: LibraryModel(),
            language: .turkish,
            appearance: .darkAqua,
            to: output.appendingPathComponent("welcome-tr-dark.png")
        )

        let mediaDirectory = output.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        for index in 1...8 {
            let url = mediaDirectory.appendingPathComponent(String(format: "%02d-audit.wav", index))
            try makeWave(at: url)
            var track = try MetadataService.read(url)
            track.title = "Release Audit Track \(index)"
            track.artist = index.isMultiple(of: 2) ? "kittenTag Artist" : "Second Artist"
            track.album = "Disposable UI Audit"
            track.releaseDate = "2026"
            track.trackNumber = "\(index)"
            track.coverData = try makeArtwork(index: index)
            try MetadataService.write(track)
        }

        let populatedLibrary = LibraryModel()
        populatedLibrary.add(urls: [mediaDirectory])
        while populatedLibrary.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(populatedLibrary.tracks.count, 8)
        populatedLibrary.selection = [try XCTUnwrap(populatedLibrary.tracks.first?.id)]

        try render(
            library: populatedLibrary,
            language: .english,
            appearance: .aqua,
            to: output.appendingPathComponent("editor-en-light.png")
        )
        try render(
            library: populatedLibrary,
            language: .turkish,
            appearance: .darkAqua,
            to: output.appendingPathComponent("editor-tr-dark.png")
        )

        UserDefaults.standard.set(AppLanguagePreference.english.rawValue, forKey: AppPreferences.language)
        try renderView(
            SettingsView().environment(\.locale, AppLanguagePreference.english.locale),
            size: NSSize(width: 650, height: 650),
            appearance: .aqua,
            to: output.appendingPathComponent("settings-en-light.png")
        )
        try renderView(
            KeyboardShortcutsView().environment(\.locale, AppLanguagePreference.english.locale),
            size: NSSize(width: 590, height: 590),
            appearance: .darkAqua,
            to: output.appendingPathComponent("shortcuts-en-dark.png")
        )

        print("kittenTag UI audit snapshots: \(output.path)")
    }

    @MainActor
    private func render(
        library: LibraryModel,
        language: AppLanguagePreference,
        appearance: NSAppearance.Name,
        to destination: URL
    ) throws {
        UserDefaults.standard.set(language.rawValue, forKey: AppPreferences.language)
        let root = ContentView()
            .environmentObject(library)
            .environment(\.locale, language.locale)
        try renderView(
            root,
            size: NSSize(width: 1_280, height: 800),
            appearance: appearance,
            to: destination
        )
    }

    @MainActor
    private func renderView<V: View>(
        _ root: V,
        size: NSSize,
        appearance: NSAppearance.Name,
        to destination: URL
    ) throws {
        let sizedRoot = root.frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: sizedRoot)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: appearance)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.10))
        hosting.layoutSubtreeIfNeeded()

        let representation = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: representation)
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try data.write(to: destination, options: .atomic)
    }

    private func makeWave(at url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        try file.write(from: buffer)
    }

    private func makeArtwork(index: Int) throws -> Data {
        let image = NSImage(size: NSSize(width: 640, height: 640))
        image.lockFocus()
        NSColor(calibratedRed: 0.36 + CGFloat(index) * 0.025, green: 0.20, blue: 0.09, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 640, height: 640)).fill()
        NSColor(calibratedRed: 0.84, green: 0.60, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 150, y: 150, width: 340, height: 340)).fill()
        image.unlockFocus()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        return try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.86]))
    }
}
