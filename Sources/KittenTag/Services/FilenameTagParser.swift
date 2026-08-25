import Foundation

enum FilenameTagParser {
    static let supportedTokens: [(token: String, field: TagField)] = [
        ("{track}", .trackNumber),
        ("{title}", .title),
        ("{artist}", .artist),
        ("{album}", .album),
        ("{year}", .releaseDate),
        ("{genre}", .genre)
    ]

    static func parse(filename: String, pattern: String) -> [TagField: String]? {
        let basename = (filename as NSString).deletingPathExtension
        guard !pattern.isEmpty else { return nil }

        let tokenMap = Dictionary(uniqueKeysWithValues: supportedTokens)
        let tokenExpression = try? NSRegularExpression(pattern: #"\{[a-zA-Z]+\}"#)
        let patternRange = NSRange(pattern.startIndex..., in: pattern)
        let matches = tokenExpression?.matches(in: pattern, range: patternRange) ?? []
        guard !matches.isEmpty else { return nil }

        var regex = "^"
        var fields: [TagField] = []
        var cursor = pattern.startIndex

        for (index, match) in matches.enumerated() {
            guard let range = Range(match.range, in: pattern) else { continue }
            regex += NSRegularExpression.escapedPattern(for: String(pattern[cursor..<range.lowerBound]))
            let token = String(pattern[range])
            guard let field = tokenMap[token] else { return nil }
            regex += index == matches.count - 1 ? "(.+)" : "(.+?)"
            fields.append(field)
            cursor = range.upperBound
        }
        regex += NSRegularExpression.escapedPattern(for: String(pattern[cursor...])) + "$"

        guard let expression = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return nil }
        let basenameRange = NSRange(basename.startIndex..., in: basename)
        guard let match = expression.firstMatch(in: basename, range: basenameRange) else { return nil }

        var result: [TagField: String] = [:]
        for (index, field) in fields.enumerated() {
            guard let range = Range(match.range(at: index + 1), in: basename) else { continue }
            result[field] = String(basename[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}
