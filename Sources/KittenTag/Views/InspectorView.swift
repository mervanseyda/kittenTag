import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    @EnvironmentObject private var library: LibraryModel
    @State private var edit = BatchEdit()
    @State private var editSelection: Set<URL> = []
    @State private var suggestionCache: [TagField: [String]] = [:]
    @State private var isCoverTargeted = false
    @State private var showsCoverOptimizer = false
    @State private var showsDiscardConfirmation = false
    var focusedElement: FocusState<AppFocus?>.Binding
    let save: () -> Void

    private let fieldOrder: [TagField] = [
        .title, .artist, .album, .albumArtist, .genre, .releaseDate,
        .composer, .copyright, .trackNumber, .trackTotal, .discNumber, .discTotal, .comment
    ]

    private var selected: [Track] { library.selectedTracks }
    private var selectionKey: String { library.selection.map(\.path).sorted().joined(separator: "|") }

    var body: some View {
        Group {
            if selected.isEmpty {
                InspectorEmptyState()
            } else {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            coverSection
                            Divider()
                            fields
                        }
                        .padding(KTLayout.pagePadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OverlayScrollerConfigurator())
                    }
                    Divider()
                    HStack(spacing: 12) {
                        Text(saveStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            showsDiscardConfirmation = true
                        } label: {
                            Label(L10n.string("Geri Al"), systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(KTButtonStyle())
                        .disabled(library.dirtyIDs.isEmpty || library.isSaving)
                        .help(L10n.string("Kaydedilmemiş değişiklikleri geri al"))

                        Button {
                            save()
                        } label: {
                            Label(L10n.string(library.isSaving ? "Kaydediliyor" : "Kaydet"), systemImage: "square.and.arrow.down")
                                .frame(minWidth: 76)
                        }
                        .buttonStyle(KTButtonStyle(prominent: true))
                        .disabled(library.dirtyIDs.isEmpty || library.isSaving)
                        .focused(focusedElement, equals: .save)
                    }
                    .padding(12)
                    .background(Color.brandInspectorBg)
                }
                .background(Color.brandInspectorBg)
            }
        }
        .background(Color.brandInspectorBg)
        .onAppear {
            focusedElement.wrappedValue = selected.isEmpty ? nil : .trackTable
            refreshEditor()
        }
        .onChange(of: selectionKey) { _ in
            focusedElement.wrappedValue = selected.isEmpty ? nil : .trackTable
            refreshEditor()
        }
        .onChange(of: library.editorRevision) { _ in
            refreshEditor()
        }
        .sheet(isPresented: $showsCoverOptimizer) {
            CoverOptimizerView(
                selectedCount: selected.count,
                coverCount: selected.filter { $0.coverData != nil }.count
            ) { size, format in
                library.optimizeSelectedCovers(size: size, format: format)
            }
        }
        .alert(L10n.string("Kaydedilmemiş değişiklikler geri alınsın mı?"), isPresented: $showsDiscardConfirmation) {
            Button(L10n.string("Vazgeç"), role: .cancel) {}
            Button(L10n.string("Geri Al"), role: .destructive) {
                library.discardPendingChanges()
            }
        } message: {
            Text(L10n.format("%lld dosyada hazırlanan değişiklikler silinecek. Diskteki dosyalara dokunulmayacak.", Int64(library.dirtyIDs.count)))
        }
    }

    private var coverSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selected.count == 1 ? displayTitle(for: selected[0]) : L10n.format("%lld dosya seçili", Int64(selected.count)))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    if selected.count == 1 {
                        Text(selected[0].format.uppercased())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            ZStack {
                if let data = commonCover, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 320, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.10), radius: 7, y: 3)
                        .accessibilityLabel(L10n.string("Albüm kapağı"))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.ktSubtleFill)
                        .frame(width: 320, height: 320)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 30))
                                Text(L10n.string(coversAreMixed ? "Çeşitli kapaklar" : "Kapak yok"))
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ktBorder, lineWidth: 1)
                        }
                    }
                }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.brandTint, lineWidth: isCoverTargeted ? 2 : 0)
                    .frame(width: 324, height: 324)
            }
            .frame(maxWidth: .infinity)
            .onDrop(of: [UTType.fileURL], isTargeted: $isCoverTargeted, perform: handleCoverDrop)
            HStack(spacing: 8) {
                Button { library.chooseCover() } label: {
                    Label(L10n.string(commonCover == nil && !coversAreMixed ? "Kapak Ekle…" : "Değiştir…"), systemImage: "photo")
                }
                .buttonStyle(KTButtonStyle())

                Button { showsCoverOptimizer = true } label: {
                    Label(L10n.string("Optimize Et…"), systemImage: "photo.badge.checkmark")
                }
                .buttonStyle(KTButtonStyle())
                .disabled(selected.allSatisfy { $0.coverData == nil } || library.isOptimizingCovers)

                Button { library.setCover(nil) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(KTButtonStyle(compact: true))
                .help(L10n.string("Kapağı kaldır"))
                .accessibilityLabel("Kapağı kaldır")
                .disabled(commonCover == nil && !coversAreMixed)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldGroup {
                field("Başlık", .title)
                field("Sanatçı", .artist)
                field("Albüm", .album)
                field("Albüm sanatçısı", .albumArtist)
            }

            Divider()

            fieldGroup {
                HStack(spacing: 10) {
                    field("Tür", .genre)
                    field("Yıl / tarih", .releaseDate)
                }
                field("Besteci", .composer)
                field("Telif hakkı", .copyright)
            }

            Divider()

            fieldGroup {
                HStack(spacing: 10) {
                    field("Parça", .trackNumber)
                    field("Toplam", .trackTotal)
                }
                HStack(spacing: 10) {
                    field("Disk", .discNumber)
                    field("Toplam", .discTotal)
                }
            }

            Divider()

            fieldGroup {
                field("Yorum", .comment, axis: .vertical)
            }
        }
    }

    private func fieldGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshEditor() {
        suggestionCache = Dictionary(uniqueKeysWithValues: fieldOrder.map { ($0, buildSuggestions(for: $0)) })
        edit = library.batchEdit(for: selected)
        editSelection = library.selection
    }

    private func field(_ label: String, _ tag: TagField, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(label))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.ktSecondaryText)
            fieldInput(label: label, tag: tag, axis: axis)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func fieldInput(label: String, tag: TagField, axis: Axis) -> some View {
        if #available(macOS 14.0, *) {
            TextField(
                "",
                text: binding(for: tag),
                prompt: edit.mixed.contains(tag) ? Text(L10n.string("Çeşitli")) : nil,
                axis: axis
            )
            .ktFieldSurface(isFocused: focusedElement.wrappedValue == .tag(tag))
            .lineLimit(axis == .vertical ? 2...5 : 1...1)
            .focused(focusedElement, equals: .tag(tag))
            .accessibilityLabel(L10n.string(label))
            .onKeyPress(keys: [.tab]) { keyPress in
                guard !keyPress.modifiers.contains(.shift) else { return .ignored }
                _ = complete(tag)
                focusedElement.wrappedValue = focusAfter(tag)
                return .handled
            }
            .onKeyPress(.escape) {
                focusedElement.wrappedValue = .trackTable
                return .handled
            }
        } else {
            TextField(
                "",
                text: binding(for: tag),
                prompt: edit.mixed.contains(tag) ? Text(L10n.string("Çeşitli")) : nil,
                axis: axis
            )
            .ktFieldSurface(isFocused: focusedElement.wrappedValue == .tag(tag))
            .lineLimit(axis == .vertical ? 2...5 : 1...1)
            .focused(focusedElement, equals: .tag(tag))
            .accessibilityLabel(L10n.string(label))
        }
    }

    private func binding(for tag: TagField) -> Binding<String> {
        Binding(
            get: { edit[tag] },
            set: {
                edit[tag] = $0
                edit.mixed.remove(tag)
                edit.touched.insert(tag)
                stagePendingEdits()
            }
        )
    }

    private func focusAfter(_ tag: TagField) -> AppFocus {
        guard let index = fieldOrder.firstIndex(of: tag), index + 1 < fieldOrder.count else {
            return .save
        }
        return .tag(fieldOrder[index + 1])
    }

    private func stagePendingEdits() {
        guard !edit.touched.isEmpty else { return }
        library.apply(edit, to: editSelection)
        edit.touched.removeAll()
    }

    private func suggestions(for tag: TagField) -> [String] {
        suggestionCache[tag] ?? buildSuggestions(for: tag)
    }

    private func buildSuggestions(for tag: TagField) -> [String] {
        var counts: [String: Int] = [:]
        for track in library.tracks {
            let value: String
            switch tag {
            case .title: value = track.title
            case .artist: value = track.artist
            case .album: value = track.album
            case .albumArtist: value = track.albumArtist
            case .composer: value = track.composer
            case .genre: value = track.genre
            case .releaseDate: value = track.releaseDate
            case .comment: value = track.comment
            case .copyright: value = track.copyright
            case .trackNumber: value = track.trackNumber
            case .trackTotal: value = track.trackTotal
            case .discNumber: value = track.discNumber
            case .discTotal: value = track.discTotal
            }
            if !value.isEmpty { counts[value, default: 0] += 1 }
        }
        return counts.keys.sorted {
            let leftCount = counts[$0, default: 0]
            let rightCount = counts[$1, default: 0]
            return leftCount == rightCount ? $0.localizedStandardCompare($1) == .orderedAscending : leftCount > rightCount
        }
    }

    private func complete(_ tag: TagField) -> Bool {
        let value = edit[tag].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let needle = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard let completion = suggestions(for: tag).first(where: {
            let candidate = $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return candidate.hasPrefix(needle) && candidate != needle
        }) else { return false }
        edit[tag] = completion
        edit.mixed.remove(tag)
        edit.touched.insert(tag)
        stagePendingEdits()
        return true
    }

    private func displayTitle(for track: Track) -> String {
        track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? track.url.deletingPathExtension().lastPathComponent
            : track.title
    }

    private var saveStatus: String {
        if library.isSaving {
            return L10n.format("Kaydediliyor… %lld/%lld", Int64(library.saveCompleted), Int64(library.saveTotal))
        }
        let count = library.dirtyIDs.count
        if count > 0 { return L10n.format("%lld dosyada değişiklik hazır", Int64(count)) }
        if library.lastSavedCount != nil { return L10n.string("Kaydedildi") }
        return L10n.string("Değişiklik yok")
    }

    private var commonCover: Data? {
        guard let first = selected.first?.coverData else { return nil }
        return selected.dropFirst().allSatisfy { $0.coverData == first } ? first : nil
    }

    private var coversAreMixed: Bool {
        guard let first = selected.first else { return false }
        return selected.dropFirst().contains { $0.coverData != first.coverData }
    }

    private func handleCoverDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url, let data = try? Data(contentsOf: url), NSImage(data: data) != nil else { return }
            Task { @MainActor in library.setCover(data) }
        }
        return true
    }
}

private struct CoverOptimizerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var size = 1_000
    @State private var format: CoverOutputFormat = .jpeg

    let selectedCount: Int
    let coverCount: Int
    let apply: (Int, CoverOutputFormat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "photo.badge.checkmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.brandPrimaryAction)
                    .frame(width: 42, height: 42)
                    .background(Color.brandSelection, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("Kapak Görselini Optimize Et"))
                        .font(.system(size: 17, weight: .semibold))
                    Text(L10n.string("Seçili kapakları donanımınızla daha uyumlu hâle getirin."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text(L10n.string("Bazı taşınabilir müzik çalarlar, araç sistemleri ve eski donanımlar çok yüksek çözünürlüklü veya uyumsuz biçimdeki kapakları göstermeyebilir. Seçili dosyaların kapaklarını burada tek işlemle uygun bir kare boyuta ve formata dönüştürebilirsiniz."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Text(L10n.string("Kare boyut"))
                        .frame(width: 82, alignment: .trailing)
                    HStack(spacing: 6) {
                        TextField("1000", value: $size, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 76)
                        Text("× \(size) px")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Stepper("", value: $size, in: CoverOptimizer.sizeRange, step: 100)
                            .labelsHidden()
                    }
                    .frame(width: 210, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 12) {
                    Text(L10n.string("Çıktı"))
                        .frame(width: 82, alignment: .trailing)
                    Picker("Çıktı", selection: $format) {
                        ForEach(CoverOutputFormat.allCases) { output in
                            Text(output.rawValue).tag(output)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.ktSubtleFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(coverCount == selectedCount
                     ? L10n.string("Her dosya kendi kapağını korur; yalnızca ölçü ve biçim değiştirilir.")
                     : L10n.format("Kapak bulunan %lld / %lld dosya işlenecek. Her dosya kendi kapağını korur.", Int64(coverCount), Int64(selectedCount)))
                Text(L10n.string("Önerilen başlangıç: 1000×1000 JPEG. Kare olmayan görseller merkezden kırpılır."))
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(L10n.string("Vazgeç")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.string("Değişiklikleri Hazırla")) {
                    size = min(max(size, CoverOptimizer.sizeRange.lowerBound), CoverOptimizer.sizeRange.upperBound)
                    apply(size, format)
                    dismiss()
                }
                .buttonStyle(KTButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(coverCount == 0)
            }
        }
        .padding(24)
        .frame(width: 470)
        .background(KTInitialFocusClearer().frame(width: 1, height: 1))
        .tint(Color.brandPrimaryAction)
    }
}

private struct InspectorEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.ktSubtleFill)
                    .frame(width: 62, height: 62)
                Image(systemName: "music.note.list")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 5) {
                Text(L10n.string("Bir dosya seç"))
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.string("Etiketleri ve albüm kapağını\nburada düzenleyebilirsin."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .background(Color.brandInspectorBg)
    }
}

private struct OverlayScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configureScroller(above: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configureScroller(above: nsView) }
    }

    private func configureScroller(above view: NSView) {
        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = current as? NSScrollView {
                ScrollbarAppearance.hide(in: scrollView)
                return
            }
            ancestor = current.superview
        }
    }
}
