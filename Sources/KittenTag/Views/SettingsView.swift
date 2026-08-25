import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.language) private var language = AppLanguagePreference.system.rawValue
    @AppStorage(AppPreferences.appearance) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(AppPreferences.includeSubfolders) private var includeSubfolders = true
    @AppStorage(AppPreferences.defaultRenamePattern) private var renamePattern = FilenameTemplate.defaultPattern
    @AppStorage(AppPreferences.showSaveSummary) private var showSaveSummary = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsSection(title: "Genel") {
                        SettingsRow(
                            icon: "globe",
                            title: "Dil",
                            detail: "Türkçe veya İngilizce seçebilirsiniz."
                        ) {
                            Picker("", selection: $language) {
                                ForEach(AppLanguagePreference.allCases) { option in
                                    Text(option.title).tag(option.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 165)
                            .accessibilityLabel(L10n.string("Dil"))
                        }

                        SettingsDivider()

                        SettingsRow(
                            icon: "circle.lefthalf.filled",
                            title: "Görünüm",
                            detail: "kittenTag’in açık ve koyu görünümünü seçin."
                        ) {
                            Picker("", selection: $appearance) {
                                ForEach(AppearancePreference.allCases) { option in
                                    Text(option.title).tag(option.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 205)
                            .accessibilityLabel(L10n.string("Görünüm"))
                        }

                        SettingsDivider()

                        SettingsRow(
                            icon: "folder.badge.plus",
                            title: "Alt klasörleri tara",
                            detail: "Bir klasör eklediğinizde içindeki alt klasörleri de arar."
                        ) {
                            Toggle("", isOn: $includeSubfolders)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel(L10n.string("Alt klasörleri tara"))
                        }

                        SettingsDivider()

                        SettingsRow(
                            icon: "checklist",
                            title: "Kaydetmeden önce incele",
                            detail: "Diske yazmadan önce değişikliklerin özetini gösterir."
                        ) {
                            Toggle("", isOn: $showSaveSummary)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel(L10n.string("Kaydetmeden önce incele"))
                        }
                    }

                    SettingsSection(title: "Dosya adları") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L10n.string("Varsayılan yeniden adlandırma şablonu"))
                                        .font(.system(size: 13.5, weight: .medium))
                                    Text(L10n.string("Yeniden adlandırma ekranı bu şablonla açılır."))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(L10n.string("Varsayılana Dön")) {
                                    renamePattern = FilenameTemplate.defaultPattern
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(renamePattern == FilenameTemplate.defaultPattern)
                            }

                            TextField(L10n.string("Şablon"), text: $renamePattern)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel(L10n.string("Şablon"))

                            Text(L10n.string("Kullanılabilir alanlar: {track}, {title}, {artist}, {album}, {year}, {genre}"))
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 14)
                    }

                    ColumnSettingsCompatibilityView()
                }
                .padding(22)
            }

            Divider()

            HStack {
                Text(L10n.string("Değişiklikler anında uygulanır."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.string("Bitti")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(Color.ktCanvas)
        }
        .frame(width: 650, height: 650)
        .background(Color.brandInspectorBg)
        .background(KTInitialFocusClearer().frame(width: 1, height: 1))
        .tint(Color.brandPrimaryAction)
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.brandHoney.opacity(0.17))
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.brandTint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("Ayarlar"))
                    .font(.system(size: 21, weight: .semibold))
                Text(L10n.string("kittenTag’in çalışma biçimini kişiselleştirin."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 17)
        .background(Color.ktCanvas)
    }
}

private struct ColumnSettingsCompatibilityView: View {
    @ViewBuilder
    var body: some View {
        if #available(macOS 14.0, *) {
            ModernColumnSettingsView()
        } else {
            SettingsSection(title: "Dosya listesi") {
                SettingsRow(
                    icon: "rectangle.split.3x1",
                    title: "Sütun düzeni",
                    detail: "macOS Ventura’da temel sütunlar otomatik olarak gösterilir."
                ) {
                    EmptyView()
                }
            }
        }
    }
}

@available(macOS 14.0, *)
private struct ModernColumnSettingsView: View {
    @AppStorage(AppPreferences.tableColumnCustomization)
    private var columnCustomization = TableColumnCustomization<Track>()
    @State private var columnOrderReset = false
    @State private var columnOrderResetTask: Task<Void, Never>?

    var body: some View {
        SettingsSection(title: "Dosya listesi") {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(L10n.string("Tabloda gösterilecek sütunlar"))
                        .font(.system(size: 13.5, weight: .medium))
                    Spacer()
                    Button { resetColumnOrder() } label: {
                        Label(
                            L10n.string(columnOrderReset ? "Sıra Sıfırlandı" : "Sırayı Sıfırla"),
                            systemImage: columnOrderReset ? "checkmark" : "arrow.counterclockwise"
                        )
                    }
                    .animation(.easeInOut(duration: 0.18), value: columnOrderReset)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Grid(alignment: .leading, horizontalSpacing: 34, verticalSpacing: 10) {
                    GridRow {
                        columnToggle("Başlık", id: TableColumnID.title, defaultVisible: true)
                        columnToggle("Sanatçı", id: TableColumnID.artist, defaultVisible: true)
                        columnToggle("Albüm", id: TableColumnID.album, defaultVisible: true)
                    }
                    GridRow {
                        columnToggle("Albüm sanatçısı", id: TableColumnID.albumArtist)
                        columnToggle("Tür", id: TableColumnID.genre)
                        columnToggle("Yıl / tarih", id: TableColumnID.year)
                    }
                    GridRow {
                        columnToggle("Besteci", id: TableColumnID.composer)
                        columnToggle("Parça", id: TableColumnID.track, defaultVisible: true)
                        columnToggle("Disk", id: TableColumnID.disc)
                    }
                    GridRow {
                        columnToggle("Süre", id: TableColumnID.duration, defaultVisible: true)
                        columnToggle("Format", id: TableColumnID.format)
                        columnToggle("Bitrate", id: TableColumnID.bitrate)
                    }
                    GridRow {
                        columnToggle("Örnekleme hızı", id: TableColumnID.sampleRate)
                        Color.clear
                        Color.clear
                    }
                }

                Text(L10n.string("Dosya sütunu her zaman görünür. Diğer sütunları tablo başlıklarından sürükleyerek sıralayabilirsiniz."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
        }
    }

    private func resetColumnOrder() {
        var updatedCustomization = columnCustomization
        updatedCustomization.resetOrder()
        columnCustomization = updatedCustomization
        columnOrderResetTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) { columnOrderReset = true }
        columnOrderResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) { columnOrderReset = false }
        }
    }

    private func columnToggle(_ title: String, id: String, defaultVisible: Bool = false) -> some View {
        Toggle(L10n.string(title), isOn: columnVisibilityBinding(id: id, defaultVisible: defaultVisible))
            .toggleStyle(.checkbox)
            .font(.system(size: 12.5))
            .frame(width: 160, alignment: .leading)
    }

    private func columnVisibilityBinding(id: String, defaultVisible: Bool) -> Binding<Bool> {
        Binding(
            get: {
                switch columnCustomization[visibility: id] {
                case .visible: true
                case .hidden: false
                default: defaultVisible
                }
            },
            set: { columnCustomization[visibility: id] = $0 ? .visible : .hidden }
        )
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string(title))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 3)

            VStack(spacing: 0) {
                content
            }
            .background(Color.ktControl)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.ktBorder, lineWidth: 1)
            }
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.brandTint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string(title))
                    .font(.system(size: 13.5, weight: .medium))
                Text(L10n.string(detail))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)
            accessory
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 62)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 51)
    }
}
