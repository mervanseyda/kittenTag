import AppKit
import Foundation

enum LibraryScope: Hashable {
    case all
    case modified
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var selection: Set<URL> = []
    @Published var searchText = ""
    @Published var scope: LibraryScope = .all
    @Published var isLoading = false
    @Published var statusMessage = L10n.string("Başlamak için ses dosyalarını buraya sürükleyin.")
    @Published var errorMessage: String?
    @Published private(set) var dirtyIDs: Set<URL> = []
    @Published private(set) var isSaving = false
    @Published private(set) var loadCompleted = 0
    @Published private(set) var loadTotal = 0
    @Published private(set) var saveCompleted = 0
    @Published private(set) var saveTotal = 0
    @Published private(set) var lastSavedCount: Int?
    @Published private(set) var isOptimizingCovers = false
    @Published private(set) var editorRevision = 0
    private var savedTracks: [URL: Track] = [:]
    private var sharedCoverData: [Data: Data] = [:]

    var filteredTracks: [Track] {
        let scopedTracks = scope == .modified
            ? tracks.filter { dirtyIDs.contains($0.id) }
            : tracks
        guard !searchText.isEmpty else { return scopedTracks }
        let needle = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return scopedTracks.filter { track in
            [track.filename, track.title, track.artist, track.album, track.genre]
                .contains { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle) }
        }
    }

    var selectedTracks: [Track] { tracks.filter { selection.contains($0.id) } }

    var changeSummaries: [TrackChangeSummary] {
        tracks.compactMap { track in
            guard dirtyIDs.contains(track.id), let saved = savedTracks[track.id] else { return nil }
            var changes: [FieldChange] = []
            appendChange(L10n.string("Başlık"), saved.title, track.title, to: &changes)
            appendChange(L10n.string("Sanatçı"), saved.artist, track.artist, to: &changes)
            appendChange(L10n.string("Albüm"), saved.album, track.album, to: &changes)
            appendChange(L10n.string("Albüm sanatçısı"), saved.albumArtist, track.albumArtist, to: &changes)
            appendChange(L10n.string("Besteci"), saved.composer, track.composer, to: &changes)
            appendChange(L10n.string("Tür"), saved.genre, track.genre, to: &changes)
            appendChange(L10n.string("Yıl / tarih"), saved.releaseDate, track.releaseDate, to: &changes)
            appendChange(L10n.string("Yorum"), saved.comment, track.comment, to: &changes)
            appendChange(L10n.string("Telif hakkı"), saved.copyright, track.copyright, to: &changes)
            appendChange(L10n.string("Parça"), saved.trackNumber, track.trackNumber, to: &changes)
            appendChange(L10n.string("Parça toplamı"), saved.trackTotal, track.trackTotal, to: &changes)
            appendChange(L10n.string("Disk"), saved.discNumber, track.discNumber, to: &changes)
            appendChange(L10n.string("Disk toplamı"), saved.discTotal, track.discTotal, to: &changes)
            if saved.coverData != track.coverData {
                changes.append(FieldChange(label: L10n.string("Albüm kapağı"), before: L10n.string(saved.coverData == nil ? "Yok" : "Mevcut"), after: L10n.string(track.coverData == nil ? "Kaldırılacak" : "Değiştirilecek")))
            }
            return TrackChangeSummary(id: track.id, filename: track.filename, changes: changes)
        }
    }

    func showOpenPanel() {
        guard !isLoading else { return }
        let panel = NSOpenPanel()
        panel.title = L10n.string("Ses Dosyaları veya Klasör Seç")
        panel.prompt = L10n.string("Ekle")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }

    func add(urls: [URL]) {
        guard !isLoading else {
            statusMessage = L10n.string("Dosyalar zaten yükleniyor…")
            return
        }
        lastSavedCount = nil
        isLoading = true
        loadCompleted = 0
        loadTotal = 0
        statusMessage = L10n.string("Ses dosyaları aranıyor…")

        let includeSubfolders = UserDefaults.standard.bool(forKey: AppPreferences.includeSubfolders)
        let existingURLs = Set(tracks.map(\.url))
        Task {
            let discovered = await Task.detached(priority: .userInitiated) {
                Self.discoverAudioFiles(in: urls, includeSubfolders: includeSubfolders)
            }.value
            let audioURLs = discovered.filter { !existingURLs.contains($0) }

            guard !audioURLs.isEmpty else {
                isLoading = false
                statusMessage = discovered.isEmpty
                    ? L10n.string("Desteklenen bir ses dosyası bulunamadı.")
                    : L10n.string("Bu klasördeki desteklenen dosyalar zaten listede.")
                if discovered.isEmpty {
                    errorMessage = L10n.string("Seçtiğiniz öğelerde kittenTag’in desteklediği bir ses dosyası bulunamadı. MP3, M4A, AAC, FLAC, OGG, Opus, WAV ve AIFF dosyalarını ekleyebilirsiniz.")
                }
                return
            }

            loadTotal = audioURLs.count
            statusMessage = L10n.format("%lld ses dosyası bulundu · Etiketler hazırlanıyor…", audioURLs.count)
            await load(audioURLs)
        }
    }

    private func load(_ audioURLs: [URL]) async {
        struct LoadOutcome: Sendable {
            let index: Int
            let url: URL
            let track: Track?
            let failure: String?
        }

        // Tag parsing is I/O-heavy. Keep concurrency bounded so large folders
        // remain responsive, while using the available CPU instead of an
        // arbitrary six-file ceiling.
        let batchSize = max(6, min(ProcessInfo.processInfo.activeProcessorCount, 12))
        var loadedIDs: [URL] = []
        var failures: [String] = []
        for batchStart in stride(from: 0, to: audioURLs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, audioURLs.count)
            let outcomes = await withTaskGroup(of: LoadOutcome.self, returning: [LoadOutcome].self) { group in
                for index in batchStart..<batchEnd {
                    let url = audioURLs[index]
                    group.addTask(priority: .userInitiated) {
                        do {
                            let track = try autoreleasepool { try MetadataService.read(url) }
                            return LoadOutcome(index: index, url: url, track: track, failure: nil)
                        } catch {
                            return LoadOutcome(index: index, url: url, track: nil, failure: error.localizedDescription)
                        }
                    }
                }

                var results: [LoadOutcome] = []
                for await outcome in group { results.append(outcome) }
                return results.sorted { $0.index < $1.index }
            }

            var batchTracks: [Track] = []
            batchTracks.reserveCapacity(outcomes.count)
            for outcome in outcomes {
                if var track = outcome.track {
                    track.coverData = sharedCover(track.coverData)
                    batchTracks.append(track)
                    savedTracks[track.id] = track
                    loadedIDs.append(track.id)
                }
                if let failure = outcome.failure {
                    failures.append("\(outcome.url.lastPathComponent): \(failure)")
                }
            }

            // Publish one table mutation per batch instead of one mutation per
            // file. This avoids hundreds of full SwiftUI table refreshes for a
            // large library without delaying progress feedback.
            tracks.append(contentsOf: batchTracks)

            loadCompleted = batchEnd
            statusMessage = L10n.format("Etiketler hazırlanıyor · %lld / %lld dosya", loadCompleted, loadTotal)
            await Task.yield()
        }

        tracks.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        if selection.isEmpty, let firstLoadedID = loadedIDs.first { selection = [firstLoadedID] }
        isLoading = false
        statusMessage = L10n.format("%lld dosya eklendi · Toplam %lld", loadedIDs.count, tracks.count)
        if !failures.isEmpty {
            let heading = loadedIDs.isEmpty
                ? L10n.format("%lld dosya açılamadı.", failures.count)
                : L10n.format("%lld dosya eklendi; %lld dosya açılamadı.", loadedIDs.count, failures.count)
            let details = failures.prefix(5).joined(separator: "\n")
            let remainder = failures.count > 5 ? "\n" + L10n.format("…ve %lld dosya daha", failures.count - 5) : ""
            errorMessage = "\(heading)\n\n\(details)\(remainder)"
        }
    }

    func removeSelected() {
        lastSavedCount = nil
        let modifiedSelection = dirtyIDs.intersection(selection)
        if !modifiedSelection.isEmpty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L10n.string("Kaydedilmemiş değişiklikleri listeden çıkar?")
            alert.informativeText = L10n.format("%lld dosyadaki hazırlanmış değişiklikler kaybolacak. Diskteki dosyalara dokunulmayacak.", modifiedSelection.count)
            alert.addButton(withTitle: L10n.string("Listeden Çıkar"))
            alert.addButton(withTitle: L10n.string("Vazgeç"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        tracks.removeAll { selection.contains($0.id) }
        for id in selection { savedTracks.removeValue(forKey: id) }
        dirtyIDs.subtract(selection)
        selection.removeAll()
        rebuildSharedCoverData()
        statusMessage = L10n.string("Dosyalar listeden kaldırıldı; diskteki dosyalara dokunulmadı.")
    }

    func batchEdit(for selected: [Track]) -> BatchEdit {
        guard let first = selected.first else { return BatchEdit() }
        var edit = BatchEdit()
        for field in TagField.allCases {
            let value = value(of: field, in: first)
            if selected.dropFirst().allSatisfy({ self.value(of: field, in: $0) == value }) {
                edit[field] = value
            } else {
                edit[field] = ""
                edit.mixed.insert(field)
            }
        }
        return edit
    }

    func apply(_ edit: BatchEdit) {
        apply(edit, to: selection)
    }

    func apply(_ edit: BatchEdit, to targetIDs: Set<URL>) {
        guard !edit.touched.isEmpty else { return }
        lastSavedCount = nil
        for index in tracks.indices where targetIDs.contains(tracks[index].id) {
            for field in edit.touched { set(edit[field], field: field, on: &tracks[index]) }
            dirtyIDs.insert(tracks[index].id)
        }
        statusMessage = L10n.format("Değişiklikler %lld dosyaya hazırlandı. Kaydetmek için ⌘S.", targetIDs.count)
    }

    func setCover(_ data: Data?) {
        lastSavedCount = nil
        for index in tracks.indices where selection.contains(tracks[index].id) {
            tracks[index].coverData = data
            tracks[index].coverWasModified = true
            dirtyIDs.insert(tracks[index].id)
        }
        statusMessage = data == nil ? L10n.string("Kapak kaldırılmak üzere işaretlendi.") : L10n.format("Kapak %lld dosyaya hazırlandı.", selection.count)
    }

    func discardPendingChanges() {
        guard !dirtyIDs.isEmpty, !isSaving else { return }
        let pending = dirtyIDs
        var restored: Set<URL> = []

        for index in tracks.indices where pending.contains(tracks[index].id) {
            let id = tracks[index].id
            guard let saved = savedTracks[id] else { continue }
            tracks[index] = saved
            restored.insert(id)
        }

        dirtyIDs.subtract(restored)
        lastSavedCount = nil
        editorRevision += 1
        statusMessage = restored.isEmpty
            ? L10n.string("Geri alınabilecek bir değişiklik bulunamadı.")
            : L10n.format("%lld dosyadaki kaydedilmemiş değişiklik geri alındı.", restored.count)
    }

    func applyTagsFromFilenames(pattern: String) {
        lastSavedCount = nil
        var matched = 0
        for index in tracks.indices where selection.contains(tracks[index].id) {
            guard let values = FilenameTagParser.parse(filename: tracks[index].filename, pattern: pattern) else { continue }
            for (field, value) in values { set(value, field: field, on: &tracks[index]) }
            dirtyIDs.insert(tracks[index].id)
            matched += 1
        }
        statusMessage = L10n.format("Dosya adlarından etiketler %lld dosyaya hazırlandı. Kaydetmek için ⌘S.", matched)
    }

    func chooseCover() {
        let panel = NSOpenPanel()
        panel.title = L10n.string("Albüm Kapağı Seç")
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { setCover(try Data(contentsOf: url)) }
        catch { errorMessage = L10n.format("Kapak okunamadı: %@", error.localizedDescription) }
    }

    func optimizeSelectedCovers(size: Int, format: CoverOutputFormat) {
        let targetIDs = selection
        let inputs = tracks.compactMap { track -> (URL, Data)? in
            guard targetIDs.contains(track.id), let cover = track.coverData else { return nil }
            return (track.id, cover)
        }
        guard !inputs.isEmpty, !isOptimizingCovers else { return }

        isOptimizingCovers = true
        lastSavedCount = nil
        statusMessage = L10n.string("Kapaklar optimize ediliyor…")

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                var optimized: [URL: Data] = [:]
                var failures = 0
                for (id, data) in inputs {
                    do {
                        optimized[id] = try CoverOptimizer.optimize(data, size: size, format: format)
                    } catch {
                        failures += 1
                    }
                }
                return (optimized, failures)
            }.value

            for index in tracks.indices {
                guard let data = result.0[tracks[index].id] else { continue }
                tracks[index].coverData = data
                tracks[index].coverWasModified = true
                dirtyIDs.insert(tracks[index].id)
            }
            isOptimizingCovers = false
            if result.1 == 0 {
                statusMessage = L10n.format("%lld kapak %lld×%lld %@ olarak hazırlandı. Kaydetmek için ⌘S.", result.0.count, size, size, format.rawValue)
            } else {
                statusMessage = L10n.format("%lld kapak hazırlandı, %lld kapak işlenemedi.", result.0.count, result.1)
            }
        }
    }

    func saveChanges(completion: ((Bool) -> Void)? = nil) {
        guard !isSaving else { completion?(false); return }
        let pending = tracks.filter { dirtyIDs.contains($0.id) }
        guard !pending.isEmpty else { completion?(true); return }

        isSaving = true
        saveCompleted = 0
        saveTotal = pending.count
        statusMessage = L10n.format("Kaydediliyor… %lld/%lld", 0, pending.count)

        Task {
            var saved: Set<URL> = []
            var failures: [String] = []

            for track in pending {
                let failure = await Task.detached(priority: .userInitiated) { () -> String? in
                    do {
                        try MetadataService.write(track)
                        return nil
                    } catch {
                        return error.localizedDescription
                    }
                }.value

                if let failure {
                    failures.append("\(track.filename): \(failure)")
                } else {
                    saved.insert(track.id)
                    NSWorkspace.shared.noteFileSystemChanged(track.url.path)
                }
                saveCompleted += 1
                statusMessage = L10n.format("Kaydediliyor… %lld/%lld", saveCompleted, saveTotal)
            }

            dirtyIDs.subtract(saved)
            for index in tracks.indices where saved.contains(tracks[index].id) {
                tracks[index].coverWasModified = false
                savedTracks[tracks[index].id] = tracks[index]
            }
            isSaving = false
            lastSavedCount = failures.isEmpty ? saved.count : nil
            statusMessage = failures.isEmpty
                ? L10n.format("%lld dosya kaydedildi.", saved.count)
                : L10n.format("%lld dosya kaydedildi, %lld dosya başarısız.", saved.count, failures.count)
            if !failures.isEmpty {
                let details = failures.prefix(5).joined(separator: "\n")
                let remainder = failures.count > 5 ? "\n" + L10n.format("…ve %lld dosya daha", failures.count - 5) : ""
                errorMessage = L10n.format("%lld dosya kaydedildi; %lld dosya kaydedilemedi.\n\n%@%@", saved.count, failures.count, details, remainder)
            }
            completion?(failures.isEmpty)
        }
    }

    func renameSelected(pattern: String) {
        let selected = selectedTracks
        guard !selected.isEmpty else { return }
        let plans = selected.map { track in
            FileRenamePlan(
                source: track.url,
                destination: track.url.deletingLastPathComponent()
                    .appendingPathComponent(FilenameTemplate.filename(for: track, pattern: pattern))
            )
        }
        let renamed = Dictionary(uniqueKeysWithValues: plans.compactMap { plan in
            plan.source == plan.destination ? nil : (plan.source, plan.destination)
        })
        do {
            try FileRenameTransaction.execute(plans)
            for index in tracks.indices {
                if let newURL = renamed[tracks[index].url] { tracks[index].url = newURL }
            }
            selection = Set(selection.map { renamed[$0] ?? $0 })
            dirtyIDs = Set(dirtyIDs.map { renamed[$0] ?? $0 })
            var updatedSavedTracks: [URL: Track] = [:]
            for (_, var track) in savedTracks {
                if let newURL = renamed[track.url] { track.url = newURL }
                updatedSavedTracks[track.id] = track
            }
            savedTracks = updatedSavedTracks
            statusMessage = L10n.format("%lld dosya yeniden adlandırıldı.", renamed.count)
        } catch { errorMessage = error.localizedDescription }
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.title = L10n.string("Etiketleri CSV Olarak Dışa Aktar")
        panel.nameFieldStringValue = "kittenTag Export.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let header = ["Filename", "Title", "Artist", "Album", "Album Artist", "Year", "Genre", "Copyright", "Track", "Disc", "Duration", "Format"]
        let rows = tracks.map { track in
            [track.filename, track.title, track.artist, track.album, track.albumArtist, track.releaseDate, track.genre, track.copyright, track.trackNumber, track.discNumber, track.durationText, track.format]
        }
        let csv = ([header] + rows).map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\n")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = L10n.string("CSV dışa aktarıldı.")
        } catch { errorMessage = L10n.format("CSV yazılamadı: %@", error.localizedDescription) }
    }

    nonisolated private static func discoverAudioFiles(in urls: [URL], includeSubfolders: Bool) -> [URL] {
        var result: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
                if includeSubfolders {
                    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
                        for case let child as URL in enumerator where MetadataService.supportedExtensions.contains(child.pathExtension.lowercased()) {
                            result.append(child)
                        }
                    }
                } else if let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
                    result.append(contentsOf: children.filter { MetadataService.supportedExtensions.contains($0.pathExtension.lowercased()) })
                }
            } else if MetadataService.supportedExtensions.contains(url.pathExtension.lowercased()) {
                result.append(url)
            }
        }
        return Array(Set(result)).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func sharedCover(_ data: Data?) -> Data? {
        guard let data else { return nil }
        if let shared = sharedCoverData[data] { return shared }
        sharedCoverData[data] = data
        return data
    }

    private func rebuildSharedCoverData() {
        sharedCoverData.removeAll(keepingCapacity: true)
        for index in tracks.indices {
            tracks[index].coverData = sharedCover(tracks[index].coverData)
        }
    }

    private func value(of field: TagField, in track: Track) -> String {
        switch field {
        case .title: track.title
        case .artist: track.artist
        case .album: track.album
        case .albumArtist: track.albumArtist
        case .composer: track.composer
        case .genre: track.genre
        case .releaseDate: track.releaseDate
        case .comment: track.comment
        case .copyright: track.copyright
        case .trackNumber: track.trackNumber
        case .trackTotal: track.trackTotal
        case .discNumber: track.discNumber
        case .discTotal: track.discTotal
        }
    }

    private func set(_ value: String, field: TagField, on track: inout Track) {
        switch field {
        case .title: track.title = value
        case .artist: track.artist = value
        case .album: track.album = value
        case .albumArtist: track.albumArtist = value
        case .composer: track.composer = value
        case .genre: track.genre = value
        case .releaseDate: track.releaseDate = value
        case .comment: track.comment = value
        case .copyright: track.copyright = value
        case .trackNumber: track.trackNumber = value
        case .trackTotal: track.trackTotal = value
        case .discNumber: track.discNumber = value
        case .discTotal: track.discTotal = value
        }
    }

    private func csvCell(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }

    private func appendChange(_ label: String, _ before: String, _ after: String, to changes: inout [FieldChange]) {
        guard before != after else { return }
        changes.append(FieldChange(label: label, before: before, after: after))
    }

}
