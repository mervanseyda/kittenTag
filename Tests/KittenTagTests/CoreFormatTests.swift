import AVFoundation
import Foundation
import XCTest
@testable import KittenTag

final class CoreFormatTests: XCTestCase {
    private struct FormatCase {
        let ext: String
        let arguments: [String]
    }

    private let formats: [FormatCase] = [
        .init(ext: "wav", arguments: ["-c:a", "pcm_s16le"]),
        .init(ext: "aiff", arguments: ["-c:a", "pcm_s16be"]),
        .init(ext: "flac", arguments: ["-c:a", "flac"]),
        .init(ext: "mp3", arguments: ["-c:a", "libmp3lame", "-b:a", "192k"]),
        .init(ext: "m4a", arguments: ["-c:a", "aac", "-b:a", "192k"]),
        .init(ext: "aac", arguments: ["-c:a", "aac", "-b:a", "192k", "-f", "adts"]),
        .init(ext: "ogg", arguments: ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]),
        .init(ext: "opus", arguments: ["-c:a", "libopus", "-b:a", "128k"])
    ]

    func testCoreFormatsRoundTripMetadataWithoutDamagingAudio() throws {
        let ffmpeg = try requireFFmpeg()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-formats-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.wav")
        try makeWave(at: source)

        for format in formats {
            let url = directory.appendingPathComponent("sample.\(format.ext)")
            try run(ffmpeg, ["-y", "-loglevel", "error", "-i", source.path] + format.arguments + [url.path])
            let sizeBefore = try fileSize(url)

            var track = try MetadataService.read(url)
            XCTAssertGreaterThan(track.duration, 0, format.ext)
            track.title = "kittenTag \(format.ext.uppercased())"
            track.artist = "Test Artist"
            track.album = "Release Safety"
            track.genre = "Test"
            track.releaseDate = "2026"
            track.copyright = "© 2026 kittenTag"
            track.trackNumber = "2"
            track.trackTotal = "9"
            try MetadataService.write(track)

            let reloaded = try MetadataService.read(url)
            XCTAssertEqual(reloaded.title, track.title, format.ext)
            XCTAssertEqual(reloaded.artist, track.artist, format.ext)
            XCTAssertEqual(reloaded.album, track.album, format.ext)
            XCTAssertEqual(reloaded.genre, track.genre, format.ext)
            XCTAssertEqual(reloaded.copyright, track.copyright, format.ext)
            XCTAssertEqual(reloaded.trackNumber, "2", format.ext)
            XCTAssertEqual(reloaded.trackTotal, "9", format.ext)
            XCTAssertGreaterThan(try fileSize(url), 0, format.ext)
            XCTAssertGreaterThan(sizeBefore, 0, format.ext)

            try run(ffmpeg, ["-v", "error", "-i", url.path, "-f", "null", "-"])
        }
    }

    func testCoreFormatsRoundTripArtwork() throws {
        let ffmpeg = try requireFFmpeg()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-artwork-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.wav")
        try makeWave(at: source)
        let artwork = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFElEQVR4nGP4z8DAwMDAxMDAwMAAAA0AAf4Bq7sAAAAASUVORK5CYII="
        ))

        for format in formats {
            let url = directory.appendingPathComponent("artwork.\(format.ext)")
            try run(ffmpeg, ["-y", "-loglevel", "error", "-i", source.path] + format.arguments + [url.path])
            var track = try MetadataService.read(url)
            track.coverData = artwork
            track.coverWasModified = true
            do {
                try MetadataService.write(track)
            } catch {
                XCTFail("Artwork write failed for \(format.ext): \(error)")
                throw error
            }

            let reloaded = try MetadataService.read(url)
            XCTAssertNotNil(reloaded.coverData, format.ext)
            XCTAssertGreaterThan(reloaded.coverData?.count ?? 0, 0, format.ext)

            var withoutArtwork = reloaded
            withoutArtwork.coverData = nil
            withoutArtwork.coverWasModified = true
            try MetadataService.write(withoutArtwork)

            let reloadedWithoutArtwork = try MetadataService.read(url)
            XCTAssertNil(reloadedWithoutArtwork.coverData, format.ext)
            try run(ffmpeg, ["-v", "error", "-i", url.path, "-f", "null", "-"])
        }
    }

    func testFailedArtworkWriteLeavesOriginalFileUntouched() throws {
        let ffmpeg = try requireFFmpeg()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-atomic-save-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.wav")
        let url = directory.appendingPathComponent("atomic.mp3")
        try makeWave(at: source)
        try run(ffmpeg, ["-y", "-loglevel", "error", "-i", source.path, "-c:a", "libmp3lame", "-b:a", "192k", url.path])

        let bytesBefore = try Data(contentsOf: url)
        var track = try MetadataService.read(url)
        track.title = "Bu değişiklik diske ulaşmamalı"
        track.coverData = Data("geçerli bir görsel değil".utf8)
        track.coverWasModified = true

        XCTAssertThrowsError(try MetadataService.write(track))
        XCTAssertEqual(try Data(contentsOf: url), bytesBefore)
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .contains { $0.lastPathComponent.hasPrefix(".kittentag-") }
        )
        try run(ffmpeg, ["-v", "error", "-i", url.path, "-f", "null", "-"])
    }

    private func makeWave(at url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        try file.write(from: buffer)
    }

    private func requireFFmpeg() throws -> String {
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        throw XCTSkip("FFmpeg bulunamadı; çekirdek format matrisi çalıştırılmadı.")
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let output = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "CoreFormatTests", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: output
            ])
        }
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
}
