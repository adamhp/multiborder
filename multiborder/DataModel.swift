import SwiftUI
import PhotosUI

enum TabbedItems: Int, CaseIterable {
    case select
    case edit
    case export

    var title: String {
        switch self {
        case .select: "Select"
        case .edit: "Edit"
        case .export: "Export"
        }
    }

    var iconName: String {
        switch self {
        case .select: "photo.badge.plus"
        case .edit: "slider.horizontal.3"
        case .export: "square.and.arrow.down"
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
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ImageComposer.ComposeError.unreadable
                    }
                    result = .loaded(try await ImageComposer.thumbnail(from: data, maxPixelSize: Self.thumbnailPixelSize))
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

    var helpTextShown = false
    var selectedTab: TabbedItems = .select
    var currentIndex = 0

    var selection = [PhotosPickerItem]() {
        didSet {
            exportTask?.cancel()
            savedIDs.removeAll()
            attachments = selection.map(ImageAttachment.init)
            resetSaveStatus()
        }
    }

    private(set) var attachments = [ImageAttachment]()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var exportTask: Task<Void, Never>?
    /// Photos already added to the library with the current settings, so retrying after
    /// a partial failure only saves the rest.
    @ObservationIgnored private var savedIDs = Set<ImageAttachment.ID>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = BorderSettings.load(from: defaults)
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

    /// Starts saving the photos in the background; see `export()`.
    func startExport() {
        guard saveStatus != .saving else { return }
        exportTask = Task { await export() }
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

        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            saveStatus = .failed("Allow adding photos in Settings to save")
            return
        }

        let settings = settings
        var failures = 0
        for (index, attachment) in pending.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                guard let data = try await attachment.item.loadTransferable(type: Data.self) else {
                    throw ImageComposer.ComposeError.unreadable
                }
                let output = try await ImageComposer.render(data, settings: settings)
                try Task.checkCancellation()
                try await addToPhotoLibrary(output)
                // A copy made with settings changed since then doesn't count as saved.
                if self.settings == settings {
                    savedIDs.insert(attachment.id)
                }
            } catch {
                if Task.isCancelled { break }
                failures += 1
            }
            exportProgress = Double(index + 1) / Double(pending.count)
        }
        if Task.isCancelled {
            saveStatus = .unsaved
            exportProgress = 0
            return
        }
        saveStatus = .result(failures: failures, total: pending.count)
        if failures == 0 {
            // The batch is done; another Download deliberately saves it again.
            savedIDs.removeAll()
        }
    }
}

/// The change block runs on a Photos queue, so it must not be main-actor isolated.
private nonisolated func addToPhotoLibrary(_ data: Data) async throws {
    try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        // Keep exports at the top of Recents rather than at the original capture date.
        request.creationDate = Date()
        request.addResource(with: .photo, data: data, options: nil)
    }
}

extension BorderSettings {
    private static let storageKey = "borderSettings"

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Loads saved settings, migrating the keys used before 2.0.1.
    static func load(from defaults: UserDefaults) -> BorderSettings {
        if let data = defaults.data(forKey: storageKey),
           let settings = try? JSONDecoder().decode(BorderSettings.self, from: data) {
            return settings
        }
        var settings = BorderSettings()
        if let ratio = defaults.object(forKey: "desiredAspectRatio") as? Double, ratio != 0 {
            settings.aspectRatio = AspectRatio(legacyValue: ratio)
        }
        if let points = defaults.object(forKey: "desiredPadding") as? Double {
            // Padding used to be points on a preview roughly 400pt wide.
            let fraction = points / 400
            settings.paddingFraction = min(max(fraction, paddingRange.lowerBound), paddingRange.upperBound)
        }
        settings.exportWidth = max(defaults.integer(forKey: "desiredSize"), 0)
        if defaults.bool(forKey: "colorStored") {
            settings.borderColor = Color.Resolved(
                red: defaults.float(forKey: "colorR"),
                green: defaults.float(forKey: "colorG"),
                blue: defaults.float(forKey: "colorB")
            )
        }
        return settings
    }
}
