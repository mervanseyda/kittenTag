import SwiftUI

struct RenameView: View {
    @EnvironmentObject private var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.defaultRenamePattern) private var pattern = FilenameTemplate.defaultPattern

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("Etiketlerden Dosya Adı Oluştur")).font(.title2.weight(.semibold))
            Text(L10n.string("Kullanılabilir alanlar: {track}, {title}, {artist}, {album}, {year}, {genre}"))
                .font(.callout).foregroundStyle(.secondary)
            TextField(L10n.string("Şablon"), text: $pattern)
                .ktFieldSurface()
            GroupBox("Önizleme") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(library.selectedTracks.prefix(5)) { track in
                        HStack {
                            Text(track.filename).foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                            Text(FilenameTemplate.filename(for: track, pattern: pattern)).lineLimit(1)
                        }
                    }
                    if library.selectedTracks.count > 5 {
                        Text(L10n.format("ve %lld dosya daha…", Int64(library.selectedTracks.count - 5)))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            HStack {
                Spacer()
                Button(L10n.string("Vazgeç")) { dismiss() }
                    .buttonStyle(KTButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("Yeniden Adlandır")) {
                    library.renameSelected(pattern: pattern)
                    dismiss()
                }
                .buttonStyle(KTButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 620)
        .background(Color.ktCanvas)
        .background(KTInitialFocusClearer().frame(width: 1, height: 1))
    }
}
