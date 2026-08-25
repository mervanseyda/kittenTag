import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AppFocus: Hashable {
    case search
    case trackTable
    case tag(TagField)
    case save
}

extension Notification.Name {
    static let focusKittenTagSearch = Notification.Name("focusKittenTagSearch")
    static let saveKittenTagChanges = Notification.Name("saveKittenTagChanges")
    static let showKittenTagKeyboardGuide = Notification.Name("showKittenTagKeyboardGuide")
    static let showKittenTagSettings = Notification.Name("showKittenTagSettings")
}

struct ContentView: View {
    @EnvironmentObject private var library: LibraryModel
    @State private var isTargeted = false
    @State private var showRename = false
    @State private var showFilenameToTags = false
    @State private var showChangeSummary = false
    @State private var showKeyboardGuide = false
    @State private var showSettings = false
    @FocusState private var focusedElement: AppFocus?

    var body: some View {
        Group {
            if library.tracks.isEmpty {
                WelcomeView(isTargeted: isTargeted) { library.showOpenPanel() }
                    .transition(.opacity)
            } else {
                editorWorkspace
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.ktCanvas)
        .background(WindowChromeConfigurator())
        .overlay(alignment: .bottom) {
            if library.isLoading {
                LoadProgressToast(
                    completed: library.loadCompleted,
                    total: library.loadTotal,
                    message: library.statusMessage
                )
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .alert("kittenTag", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button(L10n.string("Tamam"), role: .cancel) { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
        .sheet(isPresented: $showRename) { RenameView() }
        .sheet(isPresented: $showFilenameToTags) { FilenameToTagsView() }
        .sheet(isPresented: $showChangeSummary) {
            ChangeSummaryView(summaries: library.changeSummaries) {
                library.saveChanges()
            }
        }
        .sheet(isPresented: $showKeyboardGuide) { KeyboardShortcutsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .animation(.easeInOut(duration: 0.18), value: library.tracks.isEmpty)
        .onChange(of: library.tracks.isEmpty) { isEmpty in
            guard !isEmpty else { return }
            DispatchQueue.main.async { focusedElement = .trackTable }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKittenTagKeyboardGuide)) { _ in
            showKeyboardGuide = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKittenTagSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveKittenTagChanges)) { _ in
            requestSave()
        }
    }

    private var editorWorkspace: some View {
        HStack(spacing: 0) {
            NavigationRail(
                showRename: { showRename = true },
                showFilenameToTags: { showFilenameToTags = true },
                showSettings: { showSettings = true }
            )
                .frame(width: KTLayout.navigationRailWidth)

            HStack(spacing: 0) {
                trackBrowser
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.ktCanvas)
                InspectorView(focusedElement: $focusedElement, save: requestSave)
                    .frame(width: KTLayout.sidebarWidth)
                    .background(Color.brandInspectorBg)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.ktBorder.opacity(0.72))
                            .frame(width: 0.5)
                            .allowsHitTesting(false)
                    }
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(library.isSaving)
        }
    }

    private var trackBrowser: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Text(L10n.string(library.scope == .modified ? "Düzenlenen Dosyalar" : "Dosyalar"))
                    .font(.system(size: 14, weight: .semibold))
                Text("\(library.filteredTracks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.ktCanvas)
            .background(WindowDragRegion())

            Divider()

            TrackTable(focusedElement: $focusedElement)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let acceptedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !acceptedProviders.isEmpty else { return false }

        Task {
            var urls: [URL] = []
            for provider in acceptedProviders {
                guard let item = try? await provider.loadItem(
                    forTypeIdentifier: UTType.fileURL.identifier,
                    options: nil
                ) else { continue }

                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
            if !urls.isEmpty { library.add(urls: urls) }
        }
        return true
    }

    private func requestSave() {
        guard !library.dirtyIDs.isEmpty, !library.isSaving else { return }
        let shouldReview = UserDefaults.standard.bool(forKey: AppPreferences.showSaveSummary)
        if shouldReview, !library.changeSummaries.isEmpty {
            showChangeSummary = true
        } else {
            library.saveChanges()
        }
    }
}

private struct NavigationRail: View {
    @EnvironmentObject private var library: LibraryModel
    @State private var showSearch = false
    let showRename: () -> Void
    let showFilenameToTags: () -> Void
    let showSettings: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Color.clear.frame(height: 42)

            Text("kT")
                .font(.custom("Haskoy-SemiBold", fixedSize: 23))
                .tracking(-1.1)
                .foregroundStyle(Color.brandRailActive)
                .frame(width: 42, height: 42)
                .accessibilityLabel("kittenTag")

            RailButton(
                title: "Tüm Dosyalar",
                systemImage: "music.note.list",
                isSelected: library.scope == .all
            ) {
                library.scope = .all
            }

            RailButton(
                title: "Değiştirilenler",
                systemImage: "square.and.pencil",
                isSelected: library.scope == .modified,
                badge: library.dirtyIDs.count
            ) {
                library.scope = .modified
            }

            Rectangle()
                .fill(Color.brandRailDivider)
                .frame(width: 30, height: 1)
                .padding(.vertical, 2)

            RailButton(
                title: "Dosya veya klasör ekle",
                systemImage: "plus",
                isDisabled: library.isLoading
            ) {
                library.showOpenPanel()
            }

            RailButton(
                title: "Dosyaları yeniden adlandır",
                systemImage: "textformat",
                isDisabled: library.selection.isEmpty || library.isSaving
            ) {
                showRename()
            }

            RailButton(
                title: "Dosya adından etiketler",
                systemImage: "tag",
                isDisabled: library.selection.isEmpty || library.isSaving
            ) {
                showFilenameToTags()
            }

            Spacer()

            RailButton(
                title: "Ara",
                systemImage: "magnifyingglass",
                isSelected: showSearch || !library.searchText.isEmpty
            ) {
                showSearch = true
            }
            .popover(
                isPresented: $showSearch,
                attachmentAnchor: .point(.trailing),
                arrowEdge: .leading
            ) {
                RailSearchPopover()
                    .environmentObject(library)
            }

            RailButton(title: "Klavye Kısayolları", systemImage: "keyboard") {
                NotificationCenter.default.post(name: .showKittenTagKeyboardGuide, object: nil)
            }

            RailButton(title: "Ayarlar", systemImage: "gearshape") {
                showSettings()
            }
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandRail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.brandRailDivider)
                .frame(width: 1)
        }
        .background(WindowDragRegion())
        .onReceive(NotificationCenter.default.publisher(for: .focusKittenTagSearch)) { _ in
            showSearch = true
        }
    }

}

private struct RailSearchPopover: View {
    @EnvironmentObject private var library: LibraryModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Dosyalarda ara"))
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.string("Başlık, sanatçı veya albüm"), text: $library.searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                if !library.searchText.isEmpty {
                    Button {
                        library.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.string("Aramayı temizle"))
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 280, height: 34)
            .background(KTControlSurface())
        }
        .padding(16)
        .onAppear {
            DispatchQueue.main.async { isFocused = true }
        }
    }
}

private struct RailButton: View {
    let title: String
    let systemImage: String
    var isSelected = false
    var isDisabled = false
    var badge = 0
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.brandRailSelection : (isHovering ? Color.brandRailHover : Color.clear))
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(iconColor.opacity(isDisabled ? 0.38 : 1))
                    .frame(width: 42, height: 42)

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brandInk)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.brandHoney, in: Capsule())
                        .offset(x: 5, y: -4)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if isSelected {
                Capsule()
                    .fill(Color.brandHoney)
                    .frame(width: 2, height: 22)
            }
        }
        .disabled(isDisabled)
        .help(L10n.string(title))
        .onHover { isHovering = $0 }
        .accessibilityLabel(L10n.string(title))
    }

    private var iconColor: Color {
        if isSelected { return .brandRailSelectionForeground }
        if isHovering { return .brandRailHoverForeground }
        return .brandRailForeground
    }
}

private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DraggableView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard event.clickCount == 2 else {
                super.mouseDown(with: event)
                return
            }

            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")?.lowercased() {
            case "minimize":
                window?.miniaturize(nil)
            case "none":
                break
            default:
                window?.performZoom(nil)
            }
        }
    }
}

/// Keeps the main window frame persistent and restores the system-owned
/// window controls to their native geometry. Scaling these buttons at the
/// layer level causes visual drift after window and display changes.
struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ConfiguratorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ConfiguratorView: NSView {
        private var didConfigureFrame = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.configureWindowControls() }
        }

        private func configureWindowControls() {
            guard let window else { return }
            if !didConfigureFrame {
                let autosaveName = NSWindow.FrameAutosaveName("kittenTagMainWindow")
                _ = window.setFrameUsingName(autosaveName)
                _ = window.setFrameAutosaveName(autosaveName)
                didConfigureFrame = true
            }

            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(type) else { continue }
                button.layer?.setAffineTransform(.identity)
            }
        }
    }
}

private struct LoadProgressToast: View {
    let completed: Int
    let total: Int
    let message: String

    var body: some View {
        HStack(spacing: 11) {
            if total > 0 {
                ProgressView(value: Double(completed), total: Double(total))
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.ktBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }
}

private struct WelcomeView: View {
    let isTargeted: Bool
    let add: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let brandWidth = min(max(geometry.size.width * 0.40, 430), 540)

            HStack(spacing: 0) {
                WelcomeBrandPanel()
                    .frame(width: brandWidth)

                Divider()

                WelcomeDropPanel(isTargeted: isTargeted, add: add)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.ktCanvas)
    }
}

private struct WelcomeBrandPanel: View {
    var body: some View {
        ZStack {
            Color.brandWelcomePanel

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 48)

                Text(L10n.string("kittenTag’e\nhoş geldiniz."))
                    .font(.custom("Haskoy-Regular", fixedSize: 49))
                    .tracking(-2.1)
                    .lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.string("Müzik arşivinizi daha düzenli, tutarlı ve kolay bulunabilir hâle getirin."))
                    .font(.custom("Haskoy-Regular", fixedSize: 17))
                    .foregroundStyle(Color.brandWelcomeMuted)
                    .lineSpacing(5)
                    .padding(.top, 24)
                    .frame(maxWidth: 340, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    WelcomeFeatureRow(icon: "tag.fill", title: "Toplu etiket düzenleme")
                    WelcomeFeatureRow(icon: "photo.on.rectangle.angled", title: "Kapak görsellerini yönetme")
                    WelcomeFeatureRow(icon: "textformat", title: "Dosyaları düzenli adlandırma")
                }
                .padding(.top, 34)

                Spacer(minLength: 48)
            }
            .foregroundStyle(Color.brandWelcomeInk)
            .padding(.horizontal, 48)
        }
    }
}

private struct WelcomeFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.brandHoney.opacity(0.20))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandWalnut)
                        .accessibilityHidden(true)
                }

            Text(L10n.string(title))
                .font(.custom("Haskoy-Regular", fixedSize: 14.5))
                .foregroundStyle(Color.brandWelcomeInk)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WelcomeDropPanel: View {
    let isTargeted: Bool
    let add: () -> Void

    var body: some View {
        ZStack {
            Color.ktCanvas

            VStack(spacing: 0) {
                WelcomeFileStack(isTargeted: isTargeted)
                    .padding(.bottom, 30)

                Text(L10n.string(isTargeted ? "Dosyaları buraya bırakın" : "Düzenlemeye başlayın"))
                    .font(.system(size: 21, weight: .semibold))
                    .padding(.bottom, 10)

                Text(L10n.string(isTargeted
                     ? "Bıraktığınızda kittenTag dosyalarınızı hazırlayacak."
                    : "Bir dosya veya klasör seçin, isterseniz sürükleyip buraya bırakın."))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 390)
                    .padding(.bottom, 25)

                Button(action: add) {
                    HStack(spacing: 28) {
                        Text(L10n.string("Dosya veya Klasör Seç"))
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(WelcomePrimaryButtonStyle())
                .accessibilityLabel(L10n.string("Dosya veya Klasör Seç"))

                KeyboardShortcutHint()
                    .padding(.top, 14)
            }
            .padding(52)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.brandHoney : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [9, 7])
                )
                .padding(28)
        }
        .animation(.easeOut(duration: 0.16), value: isTargeted)
    }
}

private struct WelcomeFileStack: View {
    let isTargeted: Bool

    var body: some View {
        ZStack {
            WelcomeBackFileCard(tint: Color.brandOlive.opacity(0.28))
                .rotationEffect(.degrees(isTargeted ? -3 : -7))
                .offset(x: isTargeted ? -16 : -27, y: isTargeted ? -2 : 4)

            WelcomeBackFileCard(tint: Color.brandHoney.opacity(0.20))
                .rotationEffect(.degrees(isTargeted ? 3 : 7))
                .offset(x: isTargeted ? 16 : 28, y: isTargeted ? -2 : 6)

            WelcomeMetadataFileCard(isTargeted: isTargeted)
        }
        .frame(width: 330, height: 198)
        .scaleEffect(isTargeted ? 1.025 : 1)
        .accessibilityHidden(true)
    }
}

private struct WelcomeBackFileCard: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.ktControl)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.ktBorder, lineWidth: 1)
            }
            .frame(width: 262, height: 154)
            .shadow(color: .black.opacity(0.055), radius: 10, y: 5)
    }
}

private struct WelcomeMetadataFileCard: View {
    let isTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "waveform")
                    Text(L10n.string("Parça 08"))
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "tag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandAmber)
            }

            HStack(spacing: 16) {
                WelcomeAlbumTile()

                VStack(alignment: .leading, spacing: 9) {
                    MetadataLine(label: "Başlık", width: 112)
                    MetadataLine(label: "Sanatçı", width: 88)
                    MetadataLine(label: "Albüm", width: 101)

                    HStack(spacing: 7) {
                        Text("FLAC")
                        Text("M4A")
                        Text("MP3")
                        Text("AAC")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.brandAmber)
                    .padding(.top, 1)
                }
            }
        }
        .padding(18)
        .frame(width: 276, height: 164)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ktControl)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isTargeted ? Color.brandHoney : Color.ktBorder, lineWidth: isTargeted ? 2 : 1)
                }
                .shadow(color: .black.opacity(0.09), radius: 17, y: 9)
        }
    }
}

private struct WelcomeAlbumTile: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.brandWalnut, Color.brandAmber, Color.brandHoney],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.brandPaper.opacity(0.20))
                .frame(width: 43, height: 43)
                .offset(x: 19, y: -18)

            Capsule()
                .fill(Color.brandWarmWhite.opacity(0.62))
                .frame(width: 59, height: 9)
                .rotationEffect(.degrees(-35))

            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.brandWarmWhite)
                .offset(x: -22, y: 22)
        }
        .frame(width: 86, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct MetadataLine: View {
    let label: String
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(label))
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.secondary)

            Capsule()
                .fill(Color.secondary.opacity(0.28))
                .frame(width: width, height: 5)
        }
    }
}

private struct KeyboardShortcutHint: View {
    var body: some View {
        HStack(spacing: 7) {
            Text(L10n.string("veya"))
                .foregroundStyle(.secondary)

            Image(systemName: "command")
                .font(.system(size: 11, weight: .semibold))
                .welcomeKeycap()

            Text("+")
                .foregroundStyle(.secondary)

            Text("O")
                .welcomeKeycap()
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("Dosya seçmek için Komut O"))
    }
}

private extension View {
    func welcomeKeycap() -> some View {
        padding(.horizontal, 7)
            .frame(height: 23)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.ktControl)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.brandWarmWhite)
            .padding(.horizontal, 20)
            .frame(height: 46)
            .background {
                Capsule()
                    .fill(configuration.isPressed ? Color.brandAmber : Color.brandWalnut)
                    .shadow(color: Color.brandWalnut.opacity(0.18), radius: 12, y: 7)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
