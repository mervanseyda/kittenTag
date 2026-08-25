import AVFoundation
import Foundation
import XCTest
@testable import KittenTag

final class BatchEditingTests: XCTestCase {
    @MainActor
    func testMixedValuesAreDistinguishedFromCommonEmptyValues() {
        let library = LibraryModel()
        let first = makeTrack(path: "/tmp/one.flac", artist: "Daft Punk")
        let second = makeTrack(path: "/tmp/two.flac", artist: "Pharrell Williams")

        let edit = library.batchEdit(for: [first, second])

        XCTAssertTrue(edit.mixed.contains(.artist))
        XCTAssertEqual(edit.artist, "")
        XCTAssertFalse(edit.mixed.contains(.album))
        XCTAssertEqual(edit.album, "")
    }

    @MainActor
    func testOnlyTouchedFieldIsPreparedForEverySelectedTrack() {
        let library = LibraryModel()
        let first = makeTrack(path: "/tmp/one.flac", artist: "Daft Punk")
        let second = makeTrack(path: "/tmp/two.flac", artist: "Pharrell Williams")
        library.tracks = [first, second]
        library.selection = [first.id, second.id]

        var edit = library.batchEdit(for: library.selectedTracks)
        edit.genre = "Electronic"
        edit.mixed.remove(.genre)
        edit.touched.insert(.genre)
        library.apply(edit)

        XCTAssertEqual(library.tracks.map(\.genre), ["Electronic", "Electronic"])
        XCTAssertEqual(library.tracks.map(\.artist), ["Daft Punk", "Pharrell Williams"])
        XCTAssertEqual(library.dirtyIDs, [first.id, second.id])
    }

    @MainActor
    func testDiscardPendingChangesRestoresLoadedMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-undo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("original.wav")
        try makeWave(at: url)
        var original = try MetadataService.read(url)
        original.title = "Original Title"
        try MetadataService.write(original)

        let library = LibraryModel()
        library.add(urls: [url])
        while library.isLoading { try await Task.sleep(for: .milliseconds(10)) }

        let loaded = try XCTUnwrap(library.tracks.first)
        library.selection = [loaded.id]
        var edit = library.batchEdit(for: library.selectedTracks)
        edit.title = "Changed Title"
        edit.touched.insert(.title)
        library.apply(edit)

        XCTAssertEqual(library.tracks.first?.title, "Changed Title")
        XCTAssertFalse(library.dirtyIDs.isEmpty)
        let revisionBeforeUndo = library.editorRevision

        library.discardPendingChanges()

        XCTAssertEqual(library.tracks.first?.title, "Original Title")
        XCTAssertTrue(library.dirtyIDs.isEmpty)
        XCTAssertEqual(library.editorRevision, revisionBeforeUndo + 1)
        XCTAssertEqual(try MetadataService.read(url).title, "Original Title")
    }

    private func makeTrack(path: String, artist: String) -> Track {
        Track(
            url: URL(fileURLWithPath: path), title: "Track", artist: artist, album: "",
            albumArtist: "", composer: "", genre: "", releaseDate: "", comment: "",
            trackNumber: "", trackTotal: "", discNumber: "", discTotal: "", coverData: nil,
            duration: 120, bitrate: 1_000, sampleRate: 44_100, format: "FLAC"
        )
    }

    private func makeWave(at url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 441))
        buffer.frameLength = 441
        try file.write(from: buffer)
    }
}
