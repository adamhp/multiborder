import SwiftUI
import Photos
import ImageIO

// Storage shared by the app and the Share-sheet action (AddBorderExtension).

/// The app group the app and its extension share; must match both targets' entitlements.
nonisolated let appGroupID = "group.com.adamhp.multiborder"

extension UserDefaults {
    /// Defaults in the app group, so the Share-sheet action sees the settings last used in
    /// the app. Settings used to live in `.standard`; the app copies them over the first time.
    static let appGroup: UserDefaults = {
        guard let group = UserDefaults(suiteName: appGroupID) else { return .standard }
        copyAppDefaults(into: group)
        return group
    }()

    /// Copies everything the app saved in its own defaults into `group`, once. Only the app
    /// can read its own defaults, so in the extension this does nothing and tries again
    /// next time; keys already in the group are kept.
    private static func copyAppDefaults(into group: UserDefaults) {
        let copiedKey = "copiedAppDefaults"
        guard !group.bool(forKey: copiedKey),
              let appDomain = UserDefaults.standard.persistentDomain(forName: "com.adamhp.multiborder")
        else { return }
        for (key, value) in appDomain where group.object(forKey: key) == nil {
            group.set(value, forKey: key)
        }
        group.set(true, forKey: copiedKey)
    }
}

extension BorderSettings {
    private static let storageKey = "borderSettings"

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Whether settings were ever saved in `defaults`, now or in the keys used before 2.0.1.
    /// Settings are saved when first changed, so this tells someone who used the app from a new install.
    static func isSaved(in defaults: UserDefaults) -> Bool {
        [storageKey, "desiredAspectRatio", "desiredPadding", "desiredSize", "colorStored"]
            .contains { defaults.object(forKey: $0) != nil }
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

/// Shared by the app's Settings tab and both share-sheet entries through the App Group: when true,
/// the share sheet skips its "Add borders with your last settings?" question.
nonisolated let shareExtensionSkipsIntroKey = "shareExtensionSkipsIntro"

/// Saves exports to the photo library, into the chosen album and with the photo's own date
/// when the settings ask for them. The change blocks run on a Photos queue, so nothing here is main-actor isolated.
nonisolated enum PhotoLibrary {

    static let defaultAlbumName = "multiborder"

    /// An album photos can be saved into.
    struct Album: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
    }

    /// Asks for the access a save needs and returns whether photos can be added. Putting photos in the album
    /// needs full or limited access to the library; when that's refused, photos are still saved, just outside it.
    static func requestAccess(album: Bool) async -> Bool {
        if album, canUseAlbum(await PHPhotoLibrary.requestAuthorization(for: .readWrite)) {
            return true
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    /// Asks for the access the album needs and returns whether it was given.
    static func requestAlbumAccess() async -> Bool {
        canUseAlbum(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private static func canUseAlbum(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    /// Adds `output`, rendered from `source`, to the library. If it can't go in the album, it's saved without it.
    static func save(_ output: Data, source: Data, settings: BorderSettings) async throws {
        // Without the photo's own date, exports go to the top of Recents rather than among the originals.
        let date = settings.keepsOriginalDate ? captureDate(of: source) ?? Date() : Date()
        if settings.savesToAlbum, let album = try? await album(id: settings.albumID, name: settings.albumName) {
            do {
                try await add(output, date: date, to: album)
                return
            } catch {
                // Falls through to saving without the album.
            }
        }
        try await add(output, date: date, to: nil)
    }

    private static func add(_ data: Data, date: Date, to album: PHAssetCollection?) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = date
            request.addResource(with: .photo, data: data, options: nil)
            if let album, let placeholder = request.placeholderForCreatedAsset {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
            }
        }
    }

    /// The user's own albums, by name; empty without access to see them. Under limited access iOS may list
    /// none, so the Settings tab also offers to name a new album.
    static func albums() -> [Album] {
        guard canUseAlbum(PHPhotoLibrary.authorizationStatus(for: .readWrite)) else { return [] }
        var albums = [Album]()
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
            .enumerateObjects { collection, _, _ in
                // Shared and synced albums can't take new photos.
                guard collection.canPerform(.addContent) else { return }
                albums.append(Album(id: collection.localIdentifier, title: collection.localizedTitle ?? ""))
            }
        return albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The current name of the album `id`, which may have been renamed in Photos since it was chosen.
    static func albumTitle(id: String) -> String? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject?.localizedTitle
    }

    /// The album called `name`, created if there isn't one.
    static func findOrCreateAlbum(named name: String) async throws -> Album? {
        guard let collection = try await collection(named: name) else { return nil }
        return Album(id: collection.localIdentifier, title: collection.localizedTitle ?? name)
    }

    /// The album `id`, or, if it's gone (or none was chosen), the one called `name`, created if needed.
    /// `nil` without the access to see albums.
    private static func album(id: String?, name: String) async throws -> PHAssetCollection? {
        guard canUseAlbum(PHPhotoLibrary.authorizationStatus(for: .readWrite)) else { return nil }
        if let id, let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject {
            return album
        }
        return try await collection(named: name)
    }

    private static func collection(named name: String) async throws -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", name)
        func existing() -> PHAssetCollection? {
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
        }
        if let album = existing() {
            return album
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }
        return existing()
    }

    /// When the photo in `data` was taken, from its EXIF capture date. EXIF dates are local times; the offset
    /// recorded with them is used when there is one, and the device's time zone otherwise.
    static func captureDate(of data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        guard let stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String
                ?? exif[kCGImagePropertyExifDateTimeDigitized] as? String
                ?? tiff[kCGImagePropertyTIFFDateTime] as? String else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
            parser.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = parser.date(from: stamp + offset) { return date }
        }
        parser.dateFormat = "yyyy:MM:dd HH:mm:ss"
        parser.timeZone = .current
        return parser.date(from: stamp)
    }
}
