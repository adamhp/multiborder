import SwiftUI
import PhotosUI
import os

enum TabbedItems: Int, CaseIterable {
    case select
    case edit
    case export
    case settings

    var title: String {
        switch self {
        case .select: "Select"
        case .edit: "Edit"
        case .export: "Export"
        case .settings: "Settings"
        }
    }

    /// Whether the tab has nothing to show until photos are picked.
    var needsPhotos: Bool { self == .edit || self == .export }

    var iconName: String {
        switch self {
        case .select: "photo.badge.plus"
        case .edit: "slider.horizontal.3"
        case .export: "square.and.arrow.down"
        case .settings: "gearshape"
        }
    }
}

@MainActor @Observable final class ImageAttachment: Identifiable {

    enum ThumbnailState {
        case unloaded
        case loading
        case loaded(ImageComposer.Thumbnail)
        case failed
    }

    static let thumbnailPixelSize = 1024

    let item: PhotosPickerItem
    let id: String
    private(set) var thumbnail: ThumbnailState = .unloaded

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(_ item: PhotosPickerItem) {
        self.item = item
        self.id = item.itemIdentifier ?? UUID().uuidString
    }

    /// Loads the thumbnail if needed. The load itself is not tied to the caller's task,
    /// so a cancelled caller never leaves the attachment stuck in `.loading`.
    func loadThumbnail() async {
        if case .loaded = thumbnail { return }
        if loadTask == nil {
            thumbnail = .loading
            let item = item
            loadTask = Task {
                let result: ThumbnailState
                do {
                    let photo = try await item.loadPhoto()
                    result = .loaded(try await ImageComposer.thumbnail(from: photo.data, filename: photo.filename,
                                                                       maxPixelSize: Self.thumbnailPixelSize))
                } catch {
                    result = .failed
                }
                guard !Task.isCancelled else { return }
                thumbnail = result
                loadTask = nil
            }
        }
        await loadTask?.value
    }

    func unloadThumbnail() {
        loadTask?.cancel()
        loadTask = nil
        thumbnail = .unloaded
    }
}

@MainActor @Observable final class DataModel {

    enum SaveStatus: Equatable {
        case unsaved
        case saving
        case success
        case failed(String)

        var isFailed: Bool {
            if case .failed = self { true } else { false }
        }

        static func result(failures: Int, total: Int) -> SaveStatus {
            if failures == 0 {
                .success
            } else if total == 1 {
                .failed("Couldn't save the photo")
            } else {
                .failed("\(failures) of \(total) photos couldn't be saved")
            }
        }
    }

    var settings: BorderSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save(to: defaults)
            // Saved copies used the old settings, so the next export saves everything again.
            savedIDs.removeAll()
            resetSaveStatus()
        }
    }

    private(set) var saveStatus: SaveStatus = .unsaved
    /// Fraction of the current export that is finished, 0...1.
    private(set) var exportProgress: Double = 0

    var selectedTab: TabbedItems = .select
    var currentIndex = 0

    /// The picked photos, derived from `attachments` so the two can't drift apart.
    /// Setting it starts a new batch.
    var selection: [PhotosPickerItem] {
        get { attachments.map(\.item) }
        set {
            exportTask?.cancel()
            savedIDs.removeAll()
            attachments = newValue.map(ImageAttachment.init)
            resetSaveStatus()
        }
    }

    private(set) var attachments = [ImageAttachment]() {
        didSet {
            // Edit and Export leave the page view without photos, so don't stay on one of them.
            if attachments.isEmpty && selectedTab.needsPhotos {
                selectedTab = .select
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    /// The running export, if any; cleared when it finishes.
    @ObservationIgnored private(set) var exportTask: Task<Void, Never>?
    /// Photos already added to the library with the current settings, so retrying after
    /// a partial failure only saves the rest.
    @ObservationIgnored private var savedIDs = Set<ImageAttachment.ID>()

    init(defaults: UserDefaults = .appGroup) {
        self.defaults = defaults
        self.settings = BorderSettings.load(from: defaults)
        self.showsWhatsNew = Self.isWhatsNewDue(in: defaults)
    }

    func resetSaveStatus() {
        guard saveStatus != .saving else { return }
        saveStatus = .unsaved
        exportProgress = 0
    }

    func clearSelection() {
        selection = []
    }

    func removeCurrent() {
        guard attachments.indices.contains(currentIndex) else { return }
        // Removing a photo changes the batch; a later Download saves whatever is still unsaved.
        exportTask?.cancel()
        attachments.remove(at: currentIndex)
        if attachments.isEmpty {
            clearSelection()
        }
        if currentIndex >= 1 {
            currentIndex -= 1
        }
        resetSaveStatus()
    }

    /// Keeps thumbnails loaded for the cards near `index` and frees the rest.
    /// Call from `.task(id:)` so a newer index cancels the previous pass.
    func loadThumbnails(around index: Int) async {
        // Debounce quick swipes.
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        let window = (index - 2)...(index + 2)
        for (offset, attachment) in attachments.enumerated() where !window.contains(offset) {
            attachment.unloadThumbnail()
        }
        let nearby = attachments.indices
            .filter { window.contains($0) }
            .sorted { abs($0 - index) < abs($1 - index) }
            .map { attachments[$0] }
        for attachment in nearby {
            guard !Task.isCancelled else { return }
            await attachment.loadThumbnail()
        }
    }

    /// Starts saving the photos in the background; see `export()`. Does nothing while an
    /// export is pending or running, so `exportTask` always refers to the one that runs.
    func startExport() {
        guard exportTask == nil else { return }
        exportTask = Task {
            await export()
            exportTask = nil
        }
    }

    // MARK: - What's New

    static let whatsNewVersionKey = "whatsNewVersion"

    /// Whether the What's New sheet is showing. Starts true once for people updating from before
    /// `WhatsNew.release`; the Settings tab can show it again.
    var showsWhatsNew = false

    /// Call when the sheet closes, so it isn't shown again for this release.
    func recordWhatsNewSeen() {
        defaults.set(WhatsNew.release, forKey: Self.whatsNewVersionKey)
    }

    /// Due when the last sheet seen was for an earlier release. Before 3.0 nothing was recorded, so
    /// then saved settings mark someone updating; a new install has none, and skips this release's sheet.
    private static func isWhatsNewDue(in defaults: UserDefaults) -> Bool {
        if let seen = defaults.string(forKey: whatsNewVersionKey) {
            return seen.compare(WhatsNew.release, options: .numeric) == .orderedAscending
        }
        guard BorderSettings.isSaved(in: defaults) else {
            defaults.set(WhatsNew.release, forKey: whatsNewVersionKey)
            return false
        }
        return true
    }

    // MARK: - Review request

    private static let completedExportsKey = "completedExports"
    private static let reviewRequestVersionKey = "reviewRequestVersion"
    /// Exports that must succeed before the app asks for a review.
    static let exportsBeforeReview = 3

    /// Exports that saved every photo, counted across launches.
    var completedExports: Int { defaults.integer(forKey: Self.completedExportsKey) }

    /// True after a few successful exports, at most once per app version.
    /// The system also limits how often the prompt actually appears.
    var isReviewRequestDue: Bool {
        completedExports >= Self.exportsBeforeReview
            && defaults.string(forKey: Self.reviewRequestVersionKey) != appVersion
    }

    func recordReviewRequest() {
        defaults.set(appVersion, forKey: Self.reviewRequestVersionKey)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Renders every photo not yet saved with the current settings and adds it to the
    /// photo library, one at a time to bound memory use. Stops early when cancelled.
    private func export() async {
        guard saveStatus != .saving, !attachments.isEmpty else { return }
        let pending = attachments.filter { !savedIDs.contains($0.id) }
        guard !pending.isEmpty else {
            // Everything left was saved before (the photos that failed were removed).
            saveStatus = .success
            savedIDs.removeAll()
            return
        }
        saveStatus = .saving
        exportProgress = 0

        guard await PhotoLibrary.requestAccess(album: settings.savesToAlbum) else {
            saveStatus = .failed("Allow adding photos in Settings to save")
            return
        }

        // Lets the export finish if the user leaves the app; cancelling it from the system UI cancels the export.
        let continued = ContinuedExport.start(total: pending.count) { [weak self] in
            self?.exportTask?.cancel()
        }
        defer { continued?.finish(success: saveStatus == .success) }

        let settings = settings
        var failures = 0
        for (index, attachment) in pending.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let photo = try await attachment.item.loadPhoto()
                let output = try await ImageComposer.render(photo.data, filename: photo.filename, settings: settings)
                try Task.checkCancellation()
                try await PhotoLibrary.save(output, source: photo.data, settings: settings)
                // A copy made with settings changed since then doesn't count as saved.
                if self.settings == settings {
                    savedIDs.insert(attachment.id)
                }
            } catch {
                if Task.isCancelled { break }
                failures += 1
            }
            exportProgress = Double(index + 1) / Double(pending.count)
            continued?.update(completed: index + 1)
        }
        if Task.isCancelled {
            saveStatus = .unsaved
            exportProgress = 0
            return
        }
        saveStatus = .result(failures: failures, total: pending.count)
        if failures == 0 {
            defaults.set(completedExports + 1, forKey: Self.completedExportsKey)
            // The batch is done; another Download deliberately saves it again.
            savedIDs.removeAll()
        }
    }
}

/// A picked photo with a border, rendered only when a share destination asks for it.
/// Shared as JPEG, which every destination accepts, even when the source is HEIC.
///
/// A picked photo's bytes and the name of the file the photo library handed them over in.
nonisolated struct PickedPhoto: Transferable {
    let data: Data
    /// e.g. "IMG_1234.HEIC"; `nil` if the photo only came as data.
    let filename: String?

    static var transferRepresentation: some TransferRepresentation {
        // As a file first, since only a file carries a name.
        FileRepresentation(importedContentType: .image) { received in
            // The file is removed once this returns, so read it now.
            PickedPhoto(data: try Data(contentsOf: received.file), filename: received.file.lastPathComponent)
        }
        DataRepresentation(importedContentType: .image) { data in
            PickedPhoto(data: data, filename: nil)
        }
    }
}

nonisolated extension PhotosPickerItem {
    /// The photo's bytes and filename, or `unreadable` if the library has nothing to give.
    func loadPhoto() async throws -> PickedPhoto {
        guard let photo = try await loadTransferable(type: PickedPhoto.self) else {
            throw ImageComposer.ComposeError.unreadable
        }
        return photo
    }
}

/// Offered as data rather than a file: Instagram's share extension rejects a file
/// representation with "Content currently unavailable" but accepts the same JPEG as data.
nonisolated struct BorderedPhoto: Transferable {
    let item: PhotosPickerItem
    let settings: BorderSettings
    /// 1-based position in the batch, shown in the share sheet's preview.
    let number: Int

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { photo in
            log.info("Share requested photo \(photo.number)")
            do {
                let picked = try await photo.item.loadPhoto()
                let output = try await ImageComposer.render(picked.data, filename: picked.filename,
                                                            settings: photo.settings, format: .jpeg)
                log.info("Shared photo \(photo.number) as \(output.count) bytes of data")
                return output
            } catch {
                log.error("Sharing photo \(photo.number) failed: \(error, privacy: .public)")
                throw error
            }
        }
    }

    private static let log = Logger(subsystem: "com.adamhp.multiborder", category: "Share")
}
