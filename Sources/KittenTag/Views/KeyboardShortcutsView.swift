import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [ShortcutSection] = [
        ShortcutSection(
            title: "Dosyalar",
            icon: "folder",
            shortcuts: [
                ShortcutItem(title: "Dosya veya klasör ekle", keys: ["⌘", "O"]),
                ShortcutItem(title: "Tüm değişiklikleri kaydet", keys: ["⌘", "S"]),
                ShortcutItem(title: "Seçilenleri listeden kaldır", keys: ["⌫"])
            ]
        ),
        ShortcutSection(
            title: "Gezinme",
            icon: "arrow.up.arrow.down",
            shortcuts: [
                ShortcutItem(title: "Parçalar arasında gezin", keys: ["↑", "↓"]),
                ShortcutItem(title: "Ayrı parçaları seçime ekle veya çıkar", keys: ["⌘", "Tıkla"]),
                ShortcutItem(title: "Aralıktaki bütün parçaları seç", keys: ["⇧", "Tıkla"]),
                ShortcutItem(title: "Tabloyu yatay kaydır", keys: ["⇧", "Tekerlek"]),
                ShortcutItem(title: "Seçili parçayı düzenlemeye başla", keys: ["↩"]),
                ShortcutItem(title: "Dosya listesine dön", keys: ["Esc"]),
                ShortcutItem(title: "Aramaya git", keys: ["⌘", "F"])
            ]
        ),
        ShortcutSection(
            title: "Etiket düzenleme",
            icon: "tag",
            shortcuts: [
                ShortcutItem(title: "Öneriyi tamamla ve sonraki alana geç", keys: ["Tab"]),
                ShortcutItem(title: "Önceki alana dön", keys: ["⇧", "Tab"])
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.brandHoney.opacity(0.18))
                    Image(systemName: "keyboard")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.brandTint)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.string("Klavye Kısayolları"))
                        .font(.system(size: 22, weight: .semibold))
                    Text(L10n.string("kittenTag’i klavyeden elinizi kaldırmadan kullanın."))
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.ktSecondaryText)
                }

                Spacer()
            }
            .padding(24)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    ForEach(sections) { section in
                        ShortcutSectionView(section: section)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack(spacing: 6) {
                Text(L10n.string("Bu rehberi her zaman"))
                    .font(.caption)
                    .foregroundStyle(Color.ktSecondaryText)
                ShortcutKeys(keys: ["⌘", "/"])
                Text(L10n.string("ile açabilirsiniz."))
                    .font(.caption)
                    .foregroundStyle(Color.ktSecondaryText)
                Spacer()
                Button(L10n.string("Bitti")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 590, height: 590)
        .background(Color.ktCanvas)
        .tint(Color.brandPrimaryAction)
    }
}

private struct ShortcutSectionView: View {
    let section: ShortcutSection

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(L10n.string(section.title), systemImage: section.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ktSecondaryText)

            VStack(spacing: 0) {
                ForEach(Array(section.shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    HStack(spacing: 16) {
                        Text(L10n.string(shortcut.title))
                            .font(.system(size: 13.5))
                        Spacer()
                        ShortcutKeys(keys: shortcut.keys)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 43)

                    if index < section.shortcuts.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.ktControl)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.ktBorder, lineWidth: 1)
                    }
            }
        }
    }
}

private struct ShortcutKeys: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { key in
                Text(L10n.string(key))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .frame(minWidth: key.count > 1 ? 31 : 25, minHeight: 23)
                    .padding(.horizontal, key.count > 3 ? 4 : 0)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.ktCanvas)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                            }
                    }
                    .shadow(color: .black.opacity(0.035), radius: 1, y: 1)
            }
        }
    }
}

private struct ShortcutSection: Identifiable {
    let title: String
    let icon: String
    let shortcuts: [ShortcutItem]
    var id: String { title }
}

private struct ShortcutItem: Identifiable {
    let title: String
    let keys: [String]
    var id: String { title }
}
