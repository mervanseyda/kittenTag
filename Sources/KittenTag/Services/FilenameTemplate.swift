import Foundation

enum FilenameTemplate {
    static let defaultPattern = "{track} - {artist} - {title}"

    static func filename(for track: Track, pattern: String) -> String {
        let replacements = [
            "{track}": paddedTrack(track.trackNumber),
            "{title}": track.title,
            "{artist}": track.artist,
            "{album}": track.album,
            "{year}": track.releaseDate,
            "{genre}": track.genre
        ]
        var result = pattern
        for (token, value) in replacements {
            result = result.replacingOccurrences(of: token, with: value)
        }
        result = sanitize(result).trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty { result = track.url.deletingPathExtension().lastPathComponent }
        return result + "." + track.url.pathExtension
    }

    private static func paddedTrack(_ value: String) -> String {
        guard let number = Int(value) else { return value }
        return String(format: "%02d", number)
    }

    static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\0", with: "")
    }
}
