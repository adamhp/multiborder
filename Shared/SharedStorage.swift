import SwiftUI
import Photos

// Storage shared by the app and the Share-sheet action (AddBorderExtension).

/// The app group the app and its extension share; must match both targets' entitlements.
let appGroupID = "group.com.adamhp.multiborder"

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

/// The change block runs on a Photos queue, so it must not be main-actor isolated.
nonisolated func addToPhotoLibrary(_ data: Data) async throws {
    try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        // Keep exports at the top of Recents rather than at the original capture date.
        request.creationDate = Date()
        request.addResource(with: .photo, data: data, options: nil)
    }
}
