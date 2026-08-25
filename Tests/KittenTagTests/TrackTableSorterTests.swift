import Foundation
import XCTest
@testable import KittenTag

final class TrackTableSorterTests: XCTestCase {
    func testArtistSortGroupsAlbumsAndUsesNumericTrackOrder() {
        let tracks = [
            makeTrack(filename: "ten.flac", artist: "Wegh", album: "CURCUNA", track: "10"),
            makeTrack(filename: "other.flac", artist: "Sagopa Kajmer", album: "Karanlık", track: "1"),
            makeTrack(filename: "two.flac", artist: "Wegh", album: "CURCUNA", track: "02"),
            makeTrack(filename: "one.flac", artist: "Wegh", album: "CURCUNA", track: "1")
        ]

        let result = TrackTableSorter.sorted(tracks, using: [KeyPathComparator(\Track.artist)])

        XCTAssertEqual(result.map(\.filename), ["other.flac", "one.flac", "two.flac", "ten.flac"])
    }

    func testAlbumSortUsesDiscThenNumericTrackOrder() {
        var discTwo = makeTrack(filename: "disc-two.flac", artist: "Artist", album: "Album", track: "1")
        discTwo.discNumber = "2"
        var discOneTrackTen = makeTrack(filename: "track-ten.flac", artist: "Artist", album: "Album", track: "10")
        discOneTrackTen.discNumber = "1"
        var discOneTrackTwo = makeTrack(filename: "track-two.flac", artist: "Artist", album: "Album", track: "2")
        discOneTrackTwo.discNumber = "1"

        let result = TrackTableSorter.sorted(
            [discTwo, discOneTrackTen, discOneTrackTwo],
            using: [KeyPathComparator(\Track.album)]
        )

        XCTAssertEqual(result.map(\.filename), ["track-two.flac", "track-ten.flac", "disc-two.flac"])
    }

    private func makeTrack(filename: String, artist: String, album: String, track: String) -> Track {
        Track(
            url: URL(fileURLWithPath: "/tmp/\(filename)"), title: filename, artist: artist, album: album,
            albumArtist: artist, composer: "", genre: "", releaseDate: "", comment: "",
            trackNumber: track, trackTotal: "", discNumber: "", discTotal: "", coverData: nil,
            duration: 120, bitrate: 1_000, sampleRate: 44_100, format: "FLAC"
        )
    }
}
