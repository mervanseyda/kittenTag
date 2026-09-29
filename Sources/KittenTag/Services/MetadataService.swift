import AppKit
import Foundation
import ImageIO
import SPFKMetadata
import SPFKMetadataC
import UniformTypeIdentifiers

enum MetadataService {
    static let frontCoverPictureType = "Front Cover"
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "ogg", "opus",
        "wav", "wave", "aif", "aiff", "aifc"
    ]

    static func read(_ url: URL) throws -> Track {
        let metadata = try TagProperties(url: url)
        let picture = try? TagPictureRef.parsing(url: url)
        let coverData = picture.flatMap { picture in
            NSBitmapImageRep(cgImage: picture.cgImage).representation(using: .png, properties: [:])
        }
        let track = splitNumber(metadata.tag(for: .trackNumber))
        let disc = splitNumber(metadata.tag(for: .discNumber))

        return Track(
            url: url,
            title: metadata.tag(for: .title) ?? "",
            artist: metadata.tag(for: .artist) ?? "",
            album: metadata.tag(for: .album) ?? "",
            albumArtist: metadata.tag(for: .albumArtist) ?? "",
            composer: metadata.tag(for: .composer) ?? "",
            genre: metadata.tag(for: .genre) ?? "",
            releaseDate: metadata.tag(for: .date) ?? metadata.tag(for: .releaseDate) ?? "",
            comment: metadata.tag(for: .comment) ?? "",
            copyright: metadata.tag(for: .copyright) ?? "",
            trackNumber: track.number,
            trackTotal: track.total,
            discNumber: disc.number,
            discTotal: disc.total,
            coverData: coverData,
            duration: metadata.audioProperties?.duration ?? 0,
            bitrate: Int(metadata.audioProperties?.bitRate ?? 0),
            sampleRate: Int(metadata.audioProperties?.sampleRate ?? 0),
            format: url.pathExtension.uppercased()
        )
    }

    static func write(_ track: Track) throws {
        // TagLib/SPFKMetadata already chooses the format-appropriate strategy for
        // ordinary tag updates (padding/in-place writes or a rewrite when needed).
        // Avoid copying the complete audio file when artwork is unchanged.
        guard track.coverWasModified else {
            try writeInPlace(track)
            return
        }

        // Reject bad artwork before touching either the original or a staging
        // file. Cover removal intentionally has no image to validate.
        if let coverData = track.coverData, decodedImage(from: coverData) == nil {
            throw MetadataError.invalidArtwork
        }

        try ensureStagingCapacity(for: track.url)

        // Artwork updates are a multi-step operation (properties + picture). Use
        // a sibling staging copy so a picture failure cannot leave half-applied
        // metadata on the original file. A sibling also keeps the final replace
        // on the same volume.
        let fileManager = FileManager.default
        let stagingURL = track.url.deletingLastPathComponent().appendingPathComponent(
            ".kittentag-\(UUID().uuidString)-\(track.url.lastPathComponent)"
        )

        do {
            try fileManager.copyItem(at: track.url, to: stagingURL)
            var stagedTrack = track
            stagedTrack.url = stagingURL
            try writeInPlace(stagedTrack)
            try verifyWrite(of: track, at: stagingURL)
            _ = try fileManager.replaceItemAt(track.url, withItemAt: stagingURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    /// `FileManager.copyItem` creates a copy-on-write clone automatically on
    /// APFS. Other file systems need a physical copy, so make sure the volume
    /// can temporarily hold the largest item being processed. Saves are
    /// sequential; this space is reclaimed before the next track begins.
    private static func ensureStagingCapacity(for url: URL) throws {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeSupportsFileCloningKey
        ])
        guard values.volumeSupportsFileCloning != true,
              let fileSize = values.fileSize,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return }

        let safetyMargin: Int64 = 32 * 1_024 * 1_024
        let required = Int64(fileSize) + safetyMargin
        guard available >= required else {
            throw MetadataError.insufficientTemporarySpace(required: required, available: available)
        }
    }

    /// SPFKMetadata's picture bridge does not currently surface every TagLib
    /// save failure. Reopen the staging file and compare the user-visible data
    /// before it is allowed to replace the original.
    private static func verifyWrite(of expected: Track, at url: URL) throws {
        let actual: Track
        do {
            actual = try read(url)
        } catch {
            throw MetadataError.verificationFailed("file could not be reopened")
        }

        let fieldPairs: [(String, String, String)] = [
            ("title", expected.title, actual.title),
            ("artist", expected.artist, actual.artist),
            ("album", expected.album, actual.album),
            ("albumArtist", expected.albumArtist, actual.albumArtist),
            ("composer", expected.composer, actual.composer),
            ("genre", expected.genre, actual.genre),
            ("releaseDate", expected.releaseDate, actual.releaseDate),
            ("comment", expected.comment, actual.comment),
            ("copyright", expected.copyright, actual.copyright),
            ("trackNumber", expected.trackNumber, actual.trackNumber),
            ("trackTotal", expected.trackTotal, actual.trackTotal),
            ("discNumber", expected.discNumber, actual.discNumber),
            ("discTotal", expected.discTotal, actual.discTotal)
        ]
        let mismatchedFields = fieldPairs.compactMap { name, expected, actual in
            expected == actual ? nil : name
        }
        guard mismatchedFields.isEmpty else {
            throw MetadataError.verificationFailed("metadata mismatch: \(mismatchedFields.joined(separator: ", "))")
        }

        switch (expected.coverData, actual.coverData) {
        case (nil, nil):
            break
        case let (expectedData?, actualData?):
            guard artworkMatches(expectedData, actualData) else {
                throw MetadataError.verificationFailed("artwork mismatch")
            }
        default:
            throw MetadataError.verificationFailed("artwork presence mismatch")
        }

        guard actual.duration > 0, actual.format == expected.format else {
            throw MetadataError.verificationFailed("audio properties mismatch")
        }
    }

    private static func writeInPlace(_ track: Track) throws {
        // Start from the file's complete property map so fields kittenTag does not
        // currently expose (ISRC, MusicBrainz IDs, ReplayGain, etc.) survive a save.
        var properties = try TagProperties(url: track.url)
        properties.set(tag: .title, value: track.title)
        properties.set(tag: .artist, value: track.artist)
        properties.set(tag: .album, value: track.album)
        properties.set(tag: .albumArtist, value: track.albumArtist)
        properties.set(tag: .composer, value: track.composer)
        properties.set(tag: .genre, value: track.genre)
        properties.set(tag: .date, value: track.releaseDate)
        properties.set(tag: .comment, value: track.comment)
        properties.set(tag: .copyright, value: track.copyright)
        properties.set(tag: .trackNumber, value: joinedNumber(track.trackNumber, total: track.trackTotal))
        properties.set(tag: .discNumber, value: joinedNumber(track.discNumber, total: track.discTotal))
        try properties.save(to: track.url)

        if track.coverWasModified {
            if let data = track.coverData {
                guard let (image, imageType) = decodedImage(from: data) else {
                    throw MetadataError.invalidArtwork
                }
                let picture = TagPictureRef(
                    image: image,
                    utType: imageType,
                    pictureDescription: "Album cover",
                    pictureType: frontCoverPictureType
                )
                guard TagPicture.write(picture, path: track.url.path) else {
                    throw MetadataError.artworkWriteFailed
                }
                if track.url.pathExtension.lowercased() == "flac" {
                    try patchFLACPictureDimensions(at: track.url, image: image, imageType: imageType)
                }
            } else {
                guard TagPicture.write(nil, path: track.url.path) else {
                    throw MetadataError.artworkWriteFailed
                }
            }
        }
    }

    private static func splitNumber(_ value: String?) -> (number: String, total: String) {
        let pieces = (value ?? "").split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let number = pieces.first.map(String.init) ?? ""
        let total = pieces.count > 1 ? String(pieces[1]) : ""
        // MP4/M4A stores an unset track or disc number as zero. Present that as
        // an empty value, matching the other supported tag formats.
        return (number == "0" ? "" : number, total == "0" ? "" : total)
    }

    private static func joinedNumber(_ number: String, total: String) -> String {
        total.isEmpty ? number : "\(number)/\(total)"
    }

    private static func decodedImage(from data: Data) -> (CGImage, UTType)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let type = CGImageSourceGetType(source)
            .flatMap { UTType($0 as String) }
            ?? .jpeg
        return (image, type)
    }

    /// Render both inputs through the same explicit sRGB bitmap context before
    /// comparing them. Asking ImageIO to create a thumbnail directly from the
    /// original JPEG and from the PNG produced by `read(_:)` can yield different
    /// bytes for the same pixels (notably with progressive, color-profiled
    /// JPEGs), which made valid artwork writes fail verification.
    private struct ArtworkSignature {
        let width: Int
        let height: Int
        let pixels: Data
    }

    private static func artworkSignature(_ data: Data) -> ArtworkSignature? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }

        let size = 64
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return nil }

            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return ArtworkSignature(width: image.width, height: image.height, pixels: Data(buffer))
        }
    }

    private static func artworkMatches(_ lhsData: Data, _ rhsData: Data) -> Bool {
        guard let lhsSignature = artworkSignature(lhsData),
              let rhsSignature = artworkSignature(rhsData),
              lhsSignature.width == rhsSignature.width,
              lhsSignature.height == rhsSignature.height
        else { return false }

        let lhs = lhsSignature.pixels
        let rhs = rhsSignature.pixels
        guard
              lhs.count == rhs.count,
              !lhs.isEmpty
        else { return false }

        if lhs == rhs { return true }

        // TagPicture currently decodes and re-encodes JPEG artwork before
        // storing it. That necessarily changes a few pixel values even though
        // the visual content is the same. Keep the threshold tight enough to
        // reject a different cover while accepting ordinary JPEG generation
        // loss (the real-world regression fixture measures ~2.8/255 MAE).
        var totalDifference = 0
        var significantlyDifferentChannels = 0
        var channelCount = 0
        for index in lhs.indices where index % 4 != 3 {
            let difference = abs(Int(lhs[index]) - Int(rhs[index]))
            totalDifference += difference
            if difference > 16 { significantlyDifferentChannels += 1 }
            channelCount += 1
        }
        let meanAbsoluteError = Double(totalDifference) / Double(channelCount)
        let significantDifferenceRatio = Double(significantlyDifferentChannels) / Double(channelCount)
        return meanAbsoluteError <= 5 && significantDifferenceRatio <= 0.05
    }

    /// SPFKMetadata 1.4.5 writes a valid FLAC PICTURE payload but leaves the
    /// width, height and color-depth fields at zero. Players decode the JPEG/PNG
    /// anyway, while Finder's Quick Look rejects artwork declared as 0×0.
    /// Patch only those fixed-size fields in place; audio frames are untouched.
    private static func patchFLACPictureDimensions(at url: URL, image: CGImage, imageType: UTType) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 8, data.prefix(4) == Data("fLaC".utf8) else { return }

        var blockOffset = 4
        while blockOffset + 4 <= data.count {
            let header = data[blockOffset]
            let isLast = header & 0x80 != 0
            let type = header & 0x7f
            let length = Int(data[blockOffset + 1]) << 16
                | Int(data[blockOffset + 2]) << 8
                | Int(data[blockOffset + 3])
            let payloadStart = blockOffset + 4
            let payloadEnd = payloadStart + length
            guard payloadEnd <= data.count else { throw MetadataError.invalidFLACPicture }

            if type == 6 {
                var cursor = payloadStart + 4 // picture type
                guard cursor + 4 <= payloadEnd else { throw MetadataError.invalidFLACPicture }
                let mimeLength = Int(readBigEndianUInt32(data, at: cursor)); cursor += 4 + mimeLength
                guard cursor + 4 <= payloadEnd else { throw MetadataError.invalidFLACPicture }
                let descriptionLength = Int(readBigEndianUInt32(data, at: cursor)); cursor += 4 + descriptionLength
                guard cursor + 20 <= payloadEnd else { throw MetadataError.invalidFLACPicture }

                let hasAlpha = imageType.conforms(to: .png) && {
                    switch image.alphaInfo {
                    case .first, .last, .premultipliedFirst, .premultipliedLast: true
                    default: false
                    }
                }()
                let components = image.colorSpace?.numberOfComponents ?? 3
                let depth = image.bitsPerComponent * (components + (hasAlpha ? 1 : 0))
                let values: [UInt32] = [
                    UInt32(image.width), UInt32(image.height), UInt32(max(depth, 1)), 0
                ]

                let handle = try FileHandle(forUpdating: url)
                defer { try? handle.close() }
                try handle.seek(toOffset: UInt64(cursor))
                for value in values {
                    var bigEndian = value.bigEndian
                    try handle.write(contentsOf: Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size))
                }
                try handle.synchronize()
                return
            }

            blockOffset = payloadEnd
            if isLast { break }
        }
    }

    private static func readBigEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

private enum MetadataError: LocalizedError {
    case artworkWriteFailed
    case invalidArtwork
    case invalidFLACPicture
    case insufficientTemporarySpace(required: Int64, available: Int64)
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .artworkWriteFailed:
            return L10n.string("Albüm kapağı dosyaya yazılamadı.")
        case .invalidArtwork:
            return L10n.string("Seçilen albüm kapağı geçerli bir görsel değil.")
        case .invalidFLACPicture:
            return L10n.string("FLAC kapak bloğu geçersiz.")
        case let .insufficientTemporarySpace(required, available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return L10n.format("Güvenli kayıt için yeterli boş alan yok. %@ gerekli, %@ kullanılabilir.", formatter.string(fromByteCount: required), formatter.string(fromByteCount: available))
        case .verificationFailed:
            return L10n.string("Yazılan etiketler doğrulanamadı. Orijinal dosya değiştirilmedi.")
        }
    }
}
