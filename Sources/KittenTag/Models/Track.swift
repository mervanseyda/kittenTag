import Foundation

struct Track: Identifiable, Hashable, Sendable {
    var id: URL { url }
    var url: URL
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var composer: String
    var genre: String
    var releaseDate: String
    var comment: String
    var copyright: String = ""
    var trackNumber: String
    var trackTotal: String
    var discNumber: String
    var discTotal: String
    var coverData: Data?
    var duration: TimeInterval
    var bitrate: Int
    var sampleRate: Int
    var format: String
    var coverWasModified = false

    var filename: String { url.lastPathComponent }

    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "—" }
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct FieldChange: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let before: String
    let after: String
}

struct TrackChangeSummary: Identifiable, Hashable {
    var id: URL
    let filename: String
    let changes: [FieldChange]
}

enum TagField: String, CaseIterable, Hashable {
    case title, artist, album, albumArtist, composer, genre, releaseDate, comment, copyright
    case trackNumber, trackTotal, discNumber, discTotal
}

struct BatchEdit {
    var title = ""
    var artist = ""
    var album = ""
    var albumArtist = ""
    var composer = ""
    var genre = ""
    var releaseDate = ""
    var comment = ""
    var copyright = ""
    var trackNumber = ""
    var trackTotal = ""
    var discNumber = ""
    var discTotal = ""
    var touched: Set<TagField> = []
    var mixed: Set<TagField> = []

    subscript(field: TagField) -> String {
        get {
            switch field {
            case .title: title
            case .artist: artist
            case .album: album
            case .albumArtist: albumArtist
            case .composer: composer
            case .genre: genre
            case .releaseDate: releaseDate
            case .comment: comment
            case .copyright: copyright
            case .trackNumber: trackNumber
            case .trackTotal: trackTotal
            case .discNumber: discNumber
            case .discTotal: discTotal
            }
        }
        set {
            switch field {
            case .title: title = newValue
            case .artist: artist = newValue
            case .album: album = newValue
            case .albumArtist: albumArtist = newValue
            case .composer: composer = newValue
            case .genre: genre = newValue
            case .releaseDate: releaseDate = newValue
            case .comment: comment = newValue
            case .copyright: copyright = newValue
            case .trackNumber: trackNumber = newValue
            case .trackTotal: trackTotal = newValue
            case .discNumber: discNumber = newValue
            case .discTotal: discTotal = newValue
            }
        }
    }
}
