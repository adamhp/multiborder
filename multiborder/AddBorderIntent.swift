import AppIntents
import UniformTypeIdentifiers

/// "Add Border to Photos" in Shortcuts: borders photos with the settings last used in the app
/// and returns them as JPEG files, so a shortcut can save, share or pass them on.
/// It doesn't save to the photo library itself; Shortcuts' own "Save to Photo Album" does that.
/// iOS 18+: before that a list of files can't be limited to images.
@available(iOS 18, *)
struct AddBorderIntent: AppIntent, ProgressReportingIntent {
    static let title: LocalizedStringResource = "Add Border to Photos"
    static let description = IntentDescription("Adds a border to photos using the settings last used in multiborder.")

    @Parameter(title: "Photos", supportedContentTypes: [.image],
               requestValueDialog: "Which photos?")
    var photos: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Add a border to \(\.$photos)")
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let settings = BorderSettings.load(from: .appGroup)
        progress.totalUnitCount = Int64(photos.count)
        var bordered: [IntentFile] = []
        for photo in photos {
            try Task.checkCancellation()
            let output: Data
            do {
                output = try await ImageComposer.render(photo.data, filename: photo.filename,
                                                        settings: settings, keepHEIC: false)
            } catch ImageComposer.ComposeError.unreadable {
                throw UnreadablePhoto(filename: photo.filename)
            }
            let name = (photo.filename as NSString).deletingPathExtension + ".jpg"
            bordered.append(IntentFile(data: output, filename: name, type: .jpeg))
            progress.completedUnitCount += 1
        }
        return .result(value: bordered)
    }
}

struct UnreadablePhoto: Error, CustomLocalizedStringResourceConvertible {
    let filename: String
    var localizedStringResource: LocalizedStringResource {
        "multiborder couldn't read \(filename)."
    }
}

/// Offers the intent in Spotlight and to Siri without the user building a shortcut first.
@available(iOS 18, *)
struct MultiborderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddBorderIntent(),
                    phrases: ["Add a border with \(.applicationName)",
                              "Add borders to photos with \(.applicationName)"],
                    shortTitle: "Add Border",
                    systemImageName: "photo.artframe")
    }
}
