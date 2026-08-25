import SwiftUI

struct FilenameToTagsView: View {
    @EnvironmentObject private var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var pattern = FilenameTemplate.defaultPattern

    private var previews: [(track: Track, values: [TagField: String]?)] {
        library.selectedTracks.map {
            ($0, FilenameTagParser.parse(filename: $0.filename, pattern: pattern))
        }
    }

    private var matchCount: Int { previews.count { $0.values != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.string("Dosya Adından Etiketler"))
                    .font(.title2.weight(.semibold))
                Text(L10n.string("Dosya adındaki parçaları seçili etiket alanlarına ayır. Değişiklikler önce hazırlanır; Kaydet'e basana kadar diske yazılmaz."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField(L10n.string("Şablon"), text: $pattern)
                .ktFieldSurface()

            Text(L10n.string("Alanlar: {track}, {title}, {artist}, {album}, {year}, {genre}"))
                .font(.caption)
                .foregroundStyle(.secondary)

            GroupBox("Önizleme") {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(previews.prefix(12), id: \.track.id) { preview in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: preview.values == nil ? "xmark.circle" : "checkmark.circle.fill")
                                    .foregroundStyle(preview.values == nil ? Color.secondary : Color.brandAmber)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preview.track.filename)
                                        .lineLimit(1)
                                    if let values = preview.values {
                                        Text(summary(values))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    } else {
                                        Text(L10n.string("Şablonla eşleşmedi"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(7)
                }
                .frame(height: 230)
            }

            HStack {
                Text(L10n.format("%lld / %lld dosya eşleşti", Int64(matchCount), Int64(previews.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.string("Vazgeç")) { dismiss() }
                    .buttonStyle(KTButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("Etiketleri Hazırla")) {
                    library.applyTagsFromFilenames(pattern: pattern)
                    dismiss()
                }
                .buttonStyle(KTButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(matchCount == 0)
            }
        }
        .padding(22)
        .frame(width: 650)
        .background(Color.ktCanvas)
        .background(KTInitialFocusClearer().frame(width: 1, height: 1))
    }

    private func summary(_ values: [TagField: String]) -> String {
        FilenameTagParser.supportedTokens.compactMap { token, field in
            guard let value = values[field], !value.isEmpty else { return nil }
            return "\(label(field)): \(value)"
        }.joined(separator: "  ·  ")
    }

    private func label(_ field: TagField) -> String {
        switch field {
        case .trackNumber: L10n.string("Parça")
        case .title: L10n.string("Başlık")
        case .artist: L10n.string("Sanatçı")
        case .album: L10n.string("Albüm")
        case .releaseDate: L10n.string("Yıl")
        case .genre: L10n.string("Tür")
        default: field.rawValue
        }
    }
}
