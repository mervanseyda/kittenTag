import AVFoundation
import Foundation
import XCTest
@testable import KittenTag

final class FilenameTemplateTests: XCTestCase {
    func testFillsAndSanitizesTemplate() {
        XCTAssertEqual(MetadataService.frontCoverPictureType, "Front Cover")
        let track = Track(
            url: URL(fileURLWithPath: "/tmp/old.flac"), title: "A/B", artist: "Artist", album: "Album",
            albumArtist: "", composer: "", genre: "Rock", releaseDate: "2026", comment: "",
            trackNumber: "3", trackTotal: "10", discNumber: "1", discTotal: "1", coverData: nil,
            duration: 10, bitrate: 1000, sampleRate: 44_100, format: "FLAC"
        )
        XCTAssertEqual(FilenameTemplate.filename(for: track, pattern: "{track} - {artist} - {title}"), "03 - Artist - A-B.flac")
    }

    func testParsesTagsFromFilenamePattern() throws {
        let parsed = try XCTUnwrap(
            FilenameTagParser.parse(
                filename: "03 - Daft Punk - Giorgio by Moroder.flac",
                pattern: "{track} - {artist} - {title}"
            )
        )

        XCTAssertEqual(parsed[.trackNumber], "03")
        XCTAssertEqual(parsed[.artist], "Daft Punk")
        XCTAssertEqual(parsed[.title], "Giorgio by Moroder")
    }

    func testFilenameParserRejectsNonMatchingName() {
        XCTAssertNil(
            FilenameTagParser.parse(
                filename: "Giorgio by Moroder.flac",
                pattern: "{track} - {artist} - {title}"
            )
        )
    }

    func testRoundTripsRealWaveMetadata() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittenTag-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        try file.write(from: buffer)

        var track = try MetadataService.read(url)
        track.title = "kittenTag Test"
        track.artist = "Codex"
        track.trackNumber = "2"
        track.trackTotal = "8"
        try MetadataService.write(track)

        let reloaded = try MetadataService.read(url)
        XCTAssertEqual(reloaded.title, "kittenTag Test")
        XCTAssertEqual(reloaded.artist, "Codex")
        XCTAssertEqual(reloaded.trackNumber, "2")
        XCTAssertEqual(reloaded.trackTotal, "8")
    }

}
