import AppKit
import SwiftUI

struct TrackTable: View {
    var focusedElement: FocusState<AppFocus?>.Binding

    @ViewBuilder
    var body: some View {
        if #available(macOS 14.0, *) {
            ModernTrackTable(focusedElement: focusedElement)
        } else {
            VenturaTrackTable(focusedElement: focusedElement)
        }
    }
}

@available(macOS 14.0, *)
private struct ModernTrackTable: View {
    @EnvironmentObject private var library: LibraryModel
    @AppStorage(AppPreferences.tableColumnCustomization)
    private var columnCustomization = TableColumnCustomization<Track>()
    @State private var sortOrder: [KeyPathComparator<Track>] = []
    var focusedElement: FocusState<AppFocus?>.Binding

    var body: some View {
        Table(
            sortedTracks,
            selection: $library.selection,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
            TableColumn(L10n.string("Dosya"), value: \Track.filename) { track in
                HStack(spacing: 7) {
                    Text(track.filename)
                        .foregroundStyle(Color.ktSecondaryText)
                        .lineLimit(1)
                        .help(track.filename)
                    if library.dirtyIDs.contains(track.id) {
                        Circle()
                            .fill(Color.brandAmber)
                            .frame(width: 6, height: 6)
                            .help(L10n.string("Kaydedilmemiş değişiklikler"))
                            .accessibilityLabel("Kaydedilmemiş değişiklikler")
                    }
                }
            }
            .width(min: 150, ideal: 210, max: 320)

            Group {
                TableColumn(L10n.string("Başlık"), value: \Track.title) { track in
                    Text(track.title).lineLimit(1).help(track.title)
                }
                    .width(min: 100, ideal: 160, max: 280)
                    .customizationID(TableColumnID.title)

                TableColumn(L10n.string("Sanatçı"), value: \Track.artist) { track in
                    Text(track.artist).lineLimit(1).help(track.artist)
                }
                    .width(min: 72, ideal: 105, max: 190)
                    .customizationID(TableColumnID.artist)

                TableColumn(L10n.string("Albüm"), value: \Track.album) { track in
                    Text(track.album).lineLimit(1).help(track.album)
                }
                    .width(min: 90, ideal: 135, max: 260)
                    .customizationID(TableColumnID.album)
            }

            Group {
                TableColumn(L10n.string("Albüm Sanatçısı"), value: \Track.albumArtist) { track in
                    Text(track.albumArtist).lineLimit(1).help(track.albumArtist)
                }
                    .width(min: 105, ideal: 130, max: 210)
                    .customizationID(TableColumnID.albumArtist)
                    .defaultVisibility(.hidden)

                TableColumn(L10n.string("Tür"), value: \Track.genre) { track in
                    Text(track.genre).lineLimit(1).help(track.genre)
                }
                    .width(min: 65, ideal: 82, max: 150)
                    .customizationID(TableColumnID.genre)
                    .defaultVisibility(.hidden)

                TableColumn(L10n.string("Yıl / Tarih"), value: \Track.releaseDate) { track in
                    Text(track.releaseDate).lineLimit(1).help(track.releaseDate)
                }
                    .width(min: 62, ideal: 76, max: 105)
                    .customizationID(TableColumnID.year)
                    .defaultVisibility(.hidden)
            }

            Group {
                TableColumn(L10n.string("Besteci"), value: \Track.composer) { track in
                    Text(track.composer).lineLimit(1).help(track.composer)
                }
                    .width(min: 82, ideal: 110, max: 190)
                    .customizationID(TableColumnID.composer)
                    .defaultVisibility(.hidden)

                TableColumn("#", value: \Track.trackNumber)
                    .width(35)
                    .customizationID(TableColumnID.track)

                TableColumn(L10n.string("Disk"), value: \Track.discNumber)
                    .width(42)
                    .customizationID(TableColumnID.disc)
                    .defaultVisibility(.hidden)
            }

            Group {
                TableColumn(L10n.string("Süre"), value: \Track.duration) { track in
                    Text(track.durationText).monospacedDigit()
                }
                    .width(52)
                    .customizationID(TableColumnID.duration)

                TableColumn(L10n.string("Format"), value: \Track.displayFormat)
                    .width(58)
                    .customizationID(TableColumnID.format)
                    .defaultVisibility(.hidden)

                TableColumn(L10n.string("Bitrate"), value: \Track.bitrate) { track in
                    Text(track.bitrateText).monospacedDigit()
                }
                    .width(min: 68, ideal: 78, max: 100)
                    .customizationID(TableColumnID.bitrate)
                    .defaultVisibility(.hidden)
            }

            Group {
                TableColumn(L10n.string("Örnekleme"), value: \Track.sampleRate) { track in
                    Text(track.sampleRateText).monospacedDigit()
                }
                    .width(min: 72, ideal: 84, max: 110)
                    .customizationID(TableColumnID.sampleRate)
                    .defaultVisibility(.hidden)
            }
        }
        .scrollIndicators(.hidden)
        .background(
            TableBehaviorBridge()
            .allowsHitTesting(false)
        )
        .tint(Color.brandHoney)
        .focused(focusedElement, equals: .trackTable)
        .onKeyPress(.return) {
            guard !library.selection.isEmpty else { return .ignored }
            focusedElement.wrappedValue = .tag(.title)
            return .handled
        }
        .onKeyPress(.delete) {
            guard !library.selection.isEmpty, !library.isSaving else { return .ignored }
            library.removeSelected()
            return .handled
        }
        .alternatingRowBackgrounds(.disabled)
        .background(Color.ktCanvas)
        .contextMenu(forSelectionType: URL.self) { selection in
            Button(L10n.string("Listeden Kaldır"), role: .destructive) {
                library.selection = selection
                library.removeSelected()
            }
        } primaryAction: { _ in }
        .overlay {
            if library.filteredTracks.isEmpty {
                if !library.searchText.isEmpty {
                    ContentUnavailableView.search(text: library.searchText)
                } else {
                    ContentUnavailableView(L10n.string("Dosya Yok"), systemImage: "music.note", description: Text(L10n.string("Listeye bir ses dosyası ekleyin.")))
                }
            }
        }
    }

    private var sortedTracks: [Track] {
        TrackTableSorter.sorted(library.filteredTracks, using: sortOrder)
    }

}

private struct VenturaTrackTable: View {
    @EnvironmentObject private var library: LibraryModel
    @State private var sortOrder: [KeyPathComparator<Track>] = []
    var focusedElement: FocusState<AppFocus?>.Binding

    var body: some View {
        Table(sortedTracks, selection: $library.selection, sortOrder: $sortOrder) {
            TableColumn(L10n.string("Dosya"), value: \Track.filename) { track in
                HStack(spacing: 7) {
                    Text(track.filename)
                        .foregroundStyle(Color.ktSecondaryText)
                        .lineLimit(1)
                        .help(track.filename)
                    if library.dirtyIDs.contains(track.id) {
                        Circle()
                            .fill(Color.brandAmber)
                            .frame(width: 6, height: 6)
                            .help(L10n.string("Kaydedilmemiş değişiklikler"))
                    }
                }
            }
            .width(min: 150, ideal: 210, max: 320)

            TableColumn(L10n.string("Başlık"), value: \Track.title) { track in
                Text(track.title).lineLimit(1).help(track.title)
            }
            .width(min: 100, ideal: 160, max: 280)

            TableColumn(L10n.string("Sanatçı"), value: \Track.artist) { track in
                Text(track.artist).lineLimit(1).help(track.artist)
            }
            .width(min: 72, ideal: 105, max: 190)

            TableColumn(L10n.string("Albüm"), value: \Track.album) { track in
                Text(track.album).lineLimit(1).help(track.album)
            }
            .width(min: 90, ideal: 135, max: 260)

            TableColumn("#", value: \Track.trackNumber)
                .width(35)

            TableColumn(L10n.string("Süre"), value: \Track.duration) { track in
                Text(track.durationText).monospacedDigit()
            }
            .width(52)
        }
        .scrollIndicators(.hidden)
        .background(TableBehaviorBridge().allowsHitTesting(false))
        .tint(Color.brandHoney)
        .focused(focusedElement, equals: .trackTable)
        .background(Color.ktCanvas)
        .contextMenu(forSelectionType: URL.self) { selection in
            Button(L10n.string("Listeden Kaldır"), role: .destructive) {
                library.selection = selection
                library.removeSelected()
            }
        } primaryAction: { _ in }
        .overlay {
            if library.filteredTracks.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: library.searchText.isEmpty ? "music.note" : "magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                        Text(L10n.string(library.searchText.isEmpty ? "Dosya Yok" : "Sonuç bulunamadı"))
                        .font(.headline)
                    if library.searchText.isEmpty {
                        Text(L10n.string("Listeye bir ses dosyası ekleyin."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var sortedTracks: [Track] {
        TrackTableSorter.sorted(library.filteredTracks, using: sortOrder)
    }
}

enum TrackTableSorter {
    static func sorted(_ tracks: [Track], using sortOrder: [KeyPathComparator<Track>]) -> [Track] {
        guard let primary = sortOrder.first else { return tracks }
        var effectiveOrder = sortOrder

        if primary.keyPath == \Track.artist {
            appendIfMissing(KeyPathComparator(\Track.album), to: &effectiveOrder)
            appendIfMissing(KeyPathComparator(\Track.discSortNumber), to: &effectiveOrder)
            appendIfMissing(KeyPathComparator(\Track.trackSortNumber), to: &effectiveOrder)
            appendIfMissing(KeyPathComparator(\Track.filename), to: &effectiveOrder)
        } else if primary.keyPath == \Track.album || primary.keyPath == \Track.albumArtist {
            appendIfMissing(KeyPathComparator(\Track.discSortNumber), to: &effectiveOrder)
            appendIfMissing(KeyPathComparator(\Track.trackSortNumber), to: &effectiveOrder)
            appendIfMissing(KeyPathComparator(\Track.filename), to: &effectiveOrder)
        }

        return tracks.sorted(using: effectiveOrder)
    }

    private static func appendIfMissing(
        _ comparator: KeyPathComparator<Track>,
        to order: inout [KeyPathComparator<Track>]
    ) {
        guard !order.contains(where: { $0.keyPath == comparator.keyPath }) else { return }
        order.append(comparator)
    }
}

enum TableColumnID {
    static let title = "title"
    static let artist = "artist"
    static let album = "album"
    static let albumArtist = "albumArtist"
    static let genre = "genre"
    static let year = "year"
    static let composer = "composer"
    static let track = "track"
    static let disc = "disc"
    static let duration = "duration"
    static let format = "format"
    static let bitrate = "bitrate"
    static let sampleRate = "sampleRate"
}

private extension Track {
    var displayFormat: String {
        format.uppercased()
    }

    var bitrateText: String {
        bitrate > 0 ? "\(bitrate) kbps" : "—"
    }

    var sampleRateText: String {
        guard sampleRate > 0 else { return "—" }
        let value = Double(sampleRate) / 1_000
        return value.rounded() == value ? "\(Int(value)) kHz" : String(format: "%.1f kHz", value)
    }

    var trackSortNumber: Int { numericSortValue(trackNumber) }
    var discSortNumber: Int { numericSortValue(discNumber) }

    private func numericSortValue(_ value: String) -> Int {
        let firstComponent = value.split(separator: "/", maxSplits: 1).first.map(String.init) ?? value
        return Int(firstComponent.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .max
    }
}

private struct TableBehaviorBridge: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(from: nsView)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    @MainActor
    final class Coordinator: NSObject, @unchecked Sendable {
        private weak var tableView: NSTableView?
        private weak var fileColumn: NSTableColumn?
        private weak var scrollView: NSScrollView?
        private var scrollNavigator: MiniScrollNavigatorView?

        override init() {
            super.init()
        }

        func cleanup() {
            NotificationCenter.default.removeObserver(self)
            scrollNavigator?.removeFromSuperview()
        }

        func attach(from probe: NSView) {
            guard tableView == nil,
                  let root = probe.window?.contentView,
                  let table = findTable(in: root) else { return }

            tableView = table
            fileColumn = table.tableColumns.first {
                $0.headerCell.stringValue == L10n.string("Dosya")
            }
            table.selectionHighlightStyle = .regular
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(columnsDidMove(_:)),
                name: NSTableView.columnDidMoveNotification,
                object: table
            )

            if let scrollView = table.enclosingScrollView {
                ScrollbarAppearance.hide(in: scrollView)
                installScrollNavigator(in: scrollView)
            }
            pinFileColumn()
        }

        private func installScrollNavigator(in scrollView: NSScrollView) {
            self.scrollView = scrollView
            let navigator = MiniScrollNavigatorView(scrollView: scrollView)
            navigator.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(navigator, positioned: .above, relativeTo: nil)
            NSLayoutConstraint.activate([
                navigator.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),
                navigator.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12),
                navigator.widthAnchor.constraint(equalToConstant: 118),
                navigator.heightAnchor.constraint(equalToConstant: 88)
            ])
            scrollNavigator = navigator

            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollGeometryDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )

            if let documentView = scrollView.documentView {
                documentView.postsFrameChangedNotifications = true
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(scrollGeometryDidChange(_:)),
                    name: NSView.frameDidChangeNotification,
                    object: documentView
                )
            }

            navigator.updateMetrics()
        }

        @objc private func scrollGeometryDidChange(_ notification: Notification) {
            scrollNavigator?.updateMetrics()
        }

        @objc private func columnsDidMove(_ notification: Notification) {
            pinFileColumn()
        }

        private func pinFileColumn() {
            guard let tableView, let fileColumn,
                  let currentIndex = tableView.tableColumns.firstIndex(of: fileColumn),
                  currentIndex != 0 else { return }

            tableView.moveColumn(currentIndex, toColumn: 0)
        }

        private func findTable(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView { return table }
            for subview in view.subviews {
                if let table = findTable(in: subview) { return table }
            }
            return nil
        }
    }
}

/// A compact, always-available alternative to full-width scrollbars. It only
/// draws the axes that currently overflow and stays synchronized with the
/// table's native scroll view.
private final class MiniScrollNavigatorView: NSView {
    private enum Axis {
        case horizontal
        case vertical
    }

    private weak var scrollView: NSScrollView?
    private var trackingAreaReference: NSTrackingArea?
    private var hoveredAxis: Axis?
    private var draggedAxis: Axis?
    private var dragGrabOffset: CGFloat = 0
    private var horizontalProgress: CGFloat = 0
    private var verticalProgress: CGFloat = 0
    private var horizontalVisibleFraction: CGFloat = 1
    private var verticalVisibleFraction: CGFloat = 1
    private var hasHorizontalOverflow = false
    private var hasVerticalOverflow = false

    private let horizontalTrack = NSRect(x: 22, y: 6, width: 92, height: 4)
    private let verticalTrack = NSRect(x: 6, y: 22, width: 4, height: 62)

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
        alphaValue = 0.48
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.string("Tablo kaydırma denetimi"))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // AppKit already supplies this point in the receiver's coordinate
        // system. Converting it a second time made the visible controls miss
        // clicks and wheel events near the bottom-left corner.
        return axis(at: point) == nil ? nil : self
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if hasHorizontalOverflow {
            drawAxis(
                track: horizontalTrack,
                thumb: horizontalThumb,
                isActive: hoveredAxis == .horizontal || draggedAxis == .horizontal
            )
        }
        if hasVerticalOverflow {
            drawAxis(
                track: verticalTrack,
                thumb: verticalThumb,
                isActive: hoveredAxis == .vertical || draggedAxis == .vertical
            )
        }
    }

    func updateMetrics() {
        guard let scrollView, let documentView = scrollView.documentView else {
            isHidden = true
            return
        }

        let visible = scrollView.contentView.bounds
        let document = documentView.bounds
        let horizontalMaximum = max(document.width - visible.width, 0)
        let verticalMaximum = max(document.height - visible.height, 0)

        hasHorizontalOverflow = horizontalMaximum > 1
        hasVerticalOverflow = verticalMaximum > 1
        horizontalVisibleFraction = min(max(visible.width / max(document.width, 1), 0), 1)
        verticalVisibleFraction = min(max(visible.height / max(document.height, 1), 0), 1)
        horizontalProgress = horizontalMaximum > 0
            ? min(max((visible.minX - document.minX) / horizontalMaximum, 0), 1)
            : 0
        verticalProgress = verticalMaximum > 0
            ? min(max((visible.minY - document.minY) / verticalMaximum, 0), 1)
            : 0

        isHidden = !hasHorizontalOverflow && !hasVerticalOverflow
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        animateOpacity(to: 1)
        updateHoveredAxis(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredAxis(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        guard draggedAxis == nil else { return }
        hoveredAxis = nil
        needsDisplay = true
        animateOpacity(to: 0.48)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let axis = axis(at: point) else { return }
        draggedAxis = axis
        hoveredAxis = axis

        switch axis {
        case .horizontal:
            dragGrabOffset = horizontalThumb.contains(point)
                ? point.x - horizontalThumb.minX
                : horizontalThumb.width / 2
        case .vertical:
            dragGrabOffset = verticalThumb.contains(point)
                ? point.y - verticalThumb.minY
                : verticalThumb.height / 2
        }

        updateScroll(for: axis, at: point)
        NSCursor.closedHand.push()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let draggedAxis else { return }
        updateScroll(for: draggedAxis, at: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard draggedAxis != nil else { return }
        draggedAxis = nil
        NSCursor.pop()
        updateHoveredAxis(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let axis = axis(at: point), let scrollView else {
            super.scrollWheel(with: event)
            return
        }

        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
        var origin = scrollView.contentView.bounds.origin
        switch axis {
        case .horizontal:
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX
                : event.scrollingDeltaY
            origin.x -= delta * multiplier
        case .vertical:
            origin.y -= event.scrollingDeltaY * multiplier
        }
        scroll(to: origin)
    }

    private var horizontalThumb: NSRect {
        let width = max(horizontalTrack.width * horizontalVisibleFraction, 26)
        let travel = max(horizontalTrack.width - width, 0)
        return NSRect(
            x: horizontalTrack.minX + travel * horizontalProgress,
            y: horizontalTrack.minY,
            width: min(width, horizontalTrack.width),
            height: horizontalTrack.height
        )
    }

    private var verticalThumb: NSRect {
        let height = max(verticalTrack.height * verticalVisibleFraction, 24)
        let travel = max(verticalTrack.height - height, 0)
        return NSRect(
            x: verticalTrack.minX,
            y: verticalTrack.maxY - min(height, verticalTrack.height) - travel * verticalProgress,
            width: verticalTrack.width,
            height: min(height, verticalTrack.height)
        )
    }

    private func axis(at point: NSPoint) -> Axis? {
        if hasHorizontalOverflow, horizontalTrack.insetBy(dx: -10, dy: -10).contains(point) {
            return .horizontal
        }
        if hasVerticalOverflow, verticalTrack.insetBy(dx: -10, dy: -10).contains(point) {
            return .vertical
        }
        return nil
    }

    private func updateHoveredAxis(with event: NSEvent) {
        hoveredAxis = axis(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    private func updateScroll(for axis: Axis, at point: NSPoint) {
        guard let scrollView, let documentView = scrollView.documentView else { return }
        var origin = scrollView.contentView.bounds.origin

        switch axis {
        case .horizontal:
            let thumbWidth = horizontalThumb.width
            let travel = max(horizontalTrack.width - thumbWidth, 1)
            let progress = min(max((point.x - horizontalTrack.minX - dragGrabOffset) / travel, 0), 1)
            origin.x = documentView.bounds.minX
                + max(documentView.bounds.width - scrollView.contentView.bounds.width, 0) * progress
        case .vertical:
            let thumbHeight = verticalThumb.height
            let travel = max(verticalTrack.height - thumbHeight, 1)
            let progress = min(max((verticalTrack.maxY - point.y - (thumbHeight - dragGrabOffset)) / travel, 0), 1)
            origin.y = documentView.bounds.minY
                + max(documentView.bounds.height - scrollView.contentView.bounds.height, 0) * progress
        }

        scroll(to: origin)
    }

    private func scroll(to proposedOrigin: NSPoint) {
        guard let scrollView, let documentView = scrollView.documentView else { return }
        let visible = scrollView.contentView.bounds
        let document = documentView.bounds
        let maximumX = document.minX + max(document.width - visible.width, 0)
        let maximumY = document.minY + max(document.height - visible.height, 0)
        let origin = NSPoint(
            x: min(max(proposedOrigin.x, document.minX), maximumX),
            y: min(max(proposedOrigin.y, document.minY), maximumY)
        )
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        updateMetrics()
    }

    private func drawAxis(track: NSRect, thumb: NSRect, isActive: Bool) {
        let thickness: CGFloat = isActive ? 5 : 4
        let adjustedTrack = centered(rect: track, thickness: thickness)
        let adjustedThumb = centered(rect: thumb, thickness: thickness)
        NSColor.secondaryLabelColor.withAlphaComponent(isActive ? 0.19 : 0.11).setFill()
        NSBezierPath(roundedRect: adjustedTrack, xRadius: thickness / 2, yRadius: thickness / 2).fill()

        let thumbColor = NSColor(
            red: isActive ? 0.843 : 0.443,
            green: isActive ? 0.604 : 0.251,
            blue: isActive ? 0.220 : 0.122,
            alpha: isActive ? 0.95 : 0.62
        )
        thumbColor.setFill()
        NSBezierPath(roundedRect: adjustedThumb, xRadius: thickness / 2, yRadius: thickness / 2).fill()
    }

    private func centered(rect: NSRect, thickness: CGFloat) -> NSRect {
        if rect.width >= rect.height {
            return NSRect(x: rect.minX, y: rect.midY - thickness / 2, width: rect.width, height: thickness)
        }
        return NSRect(x: rect.midX - thickness / 2, y: rect.minY, width: thickness, height: rect.height)
    }

    private func animateOpacity(to value: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            animator().alphaValue = value
        }
    }
}
