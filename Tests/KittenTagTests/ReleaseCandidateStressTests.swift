import AVFoundation
import Foundation
import XCTest
@testable import KittenTag

/// An opt-in release-candidate test that builds a disposable mixed-format
/// library. It never reads or writes the user's music collection.
final class ReleaseCandidateStressTests: XCTestCase {
    private struct FormatCase {
        let ext: String
        let arguments: [String]
    }

    private let formats: [FormatCase] = [
        .init(ext: "wav", arguments: ["-c:a", "pcm_s16le"]),
        .init(ext: "aiff", arguments: ["-c:a", "pcm_s16be"]),
        .init(ext: "flac", arguments: ["-c:a", "flac"]),
        .init(ext: "mp3", arguments: ["-c:a", "libmp3lame", "-b:a", "128k"]),
        .init(ext: "m4a", arguments: ["-c:a", "aac", "-b:a", "128k"]),
        .init(ext: "aac", arguments: ["-c:a", "aac", "-b:a", "128k", "-f", "adts"]),
        .init(ext: "ogg", arguments: ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "3"]),
        .init(ext: "opus", arguments: ["-c:a", "libopus", "-b:a", "96k"])
    ]

    @MainActor
    func testDisposableFiveHundredFileReleaseCandidateWorkflow() async throws {
        guard ProcessInfo.processInfo.environment["KITTENTAG_STRESS_TEST"] == "1" else {
            throw XCTSkip("Set KITTENTAG_STRESS_TEST=1 to run the disposable 500-file release test.")
        }

        let ffmpeg = try requireFFmpeg()
        let requestedCount = Int(ProcessInfo.processInfo.environment["KITTENTAG_STRESS_COUNT"] ?? "500") ?? 500
        let count = max(requestedCount, formats.count)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-release-candidate-\(UUID().uuidString)", isDirectory: true)
        let baseDirectory = directory.appendingPathComponent("bases", isDirectory: true)
        let libraryDirectory = directory.appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = baseDirectory.appendingPathComponent("source.wav")
        try makeWave(at: source)
        var bases: [String: URL] = [:]
        for format in formats {
            let base = baseDirectory.appendingPathComponent("base.\(format.ext)")
            try run(ffmpeg, ["-y", "-loglevel", "error", "-i", source.path] + format.arguments + [base.path])
            bases[format.ext] = base
        }

        for index in 0..<count {
            let format = formats[index % formats.count]
            let sourceURL = try XCTUnwrap(bases[format.ext])
            let destination = libraryDirectory.appendingPathComponent(
                String(format: "%04d-release-test.%@", index + 1, format.ext)
            )
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        }

        let loadStart = ContinuousClock.now
        let library = LibraryModel()
        library.add(urls: [libraryDirectory])
        while library.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        let loadDuration = loadStart.duration(to: .now)
        XCTAssertNil(library.errorMessage)
        XCTAssertEqual(library.tracks.count, count)
        XCTAssertEqual(Set(library.tracks.map { $0.format.lowercased() }), Set(formats.map(\.ext)))
        XCTAssertTrue(library.tracks.allSatisfy { $0.duration > 0 })

        library.selection = Set(library.tracks.map(\.id))
        var edit = library.batchEdit(for: library.selectedTracks)
        edit.artist = "kittenTag Stress Artist"
        edit.album = "Disposable Release Candidate"
        edit.genre = "Test"
        edit.releaseDate = "2026"
        edit.touched = [.artist, .album, .genre, .releaseDate]
        library.apply(edit)
        XCTAssertEqual(library.dirtyIDs.count, count)
        let metadataSaveSucceeded = await save(library)
        XCTAssertTrue(metadataSaveSucceeded, library.errorMessage ?? "Metadata save failed")

        library.searchText = "stress artist"
        XCTAssertEqual(library.filteredTracks.count, count)
        library.searchText = "no-such-release-candidate-track"
        XCTAssertTrue(library.filteredTracks.isEmpty)
        library.searchText = ""

        let artwork = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFElEQVR4nGP4z8DAwMDAxMDAwMAAAA0AAf4Bq7sAAAAASUVORK5CYII="
        ))
        library.selection = Set(library.tracks.map(\.id))
        library.setCover(artwork)
        let artworkSaveSucceeded = await save(library)
        XCTAssertTrue(artworkSaveSucceeded, library.errorMessage ?? "Artwork save failed")
        XCTAssertEqual(try library.tracks.filter { try MetadataService.read($0.url).coverData != nil }.count, count)

        library.selection = Set(library.tracks.map(\.id))
        library.setCover(nil)
        let artworkRemovalSucceeded = await save(library)
        XCTAssertTrue(artworkRemovalSucceeded, library.errorMessage ?? "Artwork removal failed")

        for track in library.tracks {
            let reloaded = try MetadataService.read(track.url)
            XCTAssertEqual(reloaded.artist, "kittenTag Stress Artist", track.filename)
            XCTAssertEqual(reloaded.album, "Disposable Release Candidate", track.filename)
            XCTAssertEqual(reloaded.genre, "Test", track.filename)
            XCTAssertEqual(reloaded.releaseDate, "2026", track.filename)
            XCTAssertNil(reloaded.coverData, track.filename)
            XCTAssertGreaterThan(reloaded.duration, 0, track.filename)
        }

        let renamePlans = library.tracks.enumerated().map { index, track in
            FileRenamePlan(
                source: track.url,
                destination: libraryDirectory.appendingPathComponent(
                    String(format: "renamed-%04d.%@", index + 1, track.url.pathExtension)
                )
            )
        }
        try FileRenameTransaction.execute(renamePlans)
        XCTAssertTrue(renamePlans.allSatisfy { FileManager.default.fileExists(atPath: $0.destination.path) })
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(at: libraryDirectory, includingPropertiesForKeys: nil)
                .contains { $0.lastPathComponent.hasPrefix(".kittentag-") }
        )

        for format in formats {
            let representative = try XCTUnwrap(renamePlans.first { $0.destination.pathExtension == format.ext })
            try run(ffmpeg, ["-v", "error", "-i", representative.destination.path, "-f", "null", "-"])
        }

        let emptyDirectory = directory.appendingPathComponent("unsupported", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        try Data("not audio".utf8).write(to: emptyDirectory.appendingPathComponent("readme.txt"))
        let emptyLibrary = LibraryModel()
        emptyLibrary.add(urls: [emptyDirectory])
        while emptyLibrary.isLoading { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(emptyLibrary.tracks.isEmpty)
        XCTAssertNotNil(emptyLibrary.errorMessage)

        print("kittenTag RC stress: loaded \(count) mixed-format files in \(loadDuration)")
    }

    @MainActor
    private func save(_ library: LibraryModel) async -> Bool {
        await withCheckedContinuation { continuation in
            library.saveChanges { continuation.resume(returning: $0) }
        }
    }

    private func makeWave(at url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        // A tenth of a second is long enough for every supported container,
        // including raw ADTS AAC, to report a stable duration.
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        try file.write(from: buffer)
    }

    private func requireFFmpeg() throws -> String {
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        throw XCTSkip("FFmpeg is required for the release-candidate stress test.")
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
            throw NSError(domain: "ReleaseCandidateStressTests", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: output
            ])
        }
    }
}
