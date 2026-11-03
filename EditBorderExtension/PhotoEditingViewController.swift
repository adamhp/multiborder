//
//  PhotoEditingViewController.swift
//  EditBorderExtension
//
//  "multiborder" in Photos' Edit screen: the app's Edit page for one photo. Done hands Photos the
//  full-size bordered photo with the border's settings, so choosing multiborder again changes
//  that border instead of adding another. Nothing is saved to the app's settings.
//

import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import os

/// The extension's entry point (NSExtensionPrincipalClass).
final class PhotoEditingViewController: UIViewController, PHContentEditingController {

    private let session = EditingSession()
    private var input: PHContentEditingInput?
    /// The photo as Photos handed it over: the original when the border is ours, else the photo with its edits.
    private var original: Data?
    private var filename: String?
    private var format = ExportFormat.jpeg
    private var startingSettings = BorderSettings()
    /// Reads the photo and makes the preview; Done waits for it.
    private var loading: Task<Void, Never>?
    private var work: Task<Void, Never>?

    private static let log = Logger(subsystem: "com.adamhp.multiborder", category: "EditBorderExtension")

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: EditingScreen(session: session))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    // MARK: PHContentEditingController

    /// Asked only when the photo already has an edit. A border of ours gets the original photo back
    /// to redraw; anything else (a crop or filter in Photos, say) comes with its edits applied.
    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        let canHandle = PhotoEditing.canHandle(adjustmentData)
        session.hasOtherEdits = !canHandle
        return canHandle
    }

    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        input = contentEditingInput
        let defaultType = PHContentEditingOutput(contentEditingInput: contentEditingInput).defaultRenderedContentType
        format = PhotoEditing.outputFormat(defaultType: defaultType)
        // A re-edit brings back the photo's own border; a first edit starts from the app's last-used settings.
        let saved = PhotoEditing.settings(from: contentEditingInput.adjustmentData)
        startingSettings = PhotoEditing.editingSettings(saved ?? BorderSettings.load(from: .appGroup), format: format)
        session.editor = BorderEditor(settings: startingSettings, savingTo: nil)

        guard let url = contentEditingInput.fullSizeImageURL else {
            session.preview = .failed
            return
        }
        // An earlier edit's render is named FullSizeRender, which isn't the name Photos shows.
        let name = url.lastPathComponent
        filename = name.hasPrefix("FullSizeRender") ? nil : name
        Self.log.debug("Editing \(name, privacy: .public) as \(self.format.rawValue, privacy: .public)")
        loading = Task {
            do {
                let data = try await Self.read(url)
                original = data
                session.preview = .loaded(try await ImageComposer.thumbnail(from: data, filename: filename, maxPixelSize: 1024))
            } catch {
                Self.log.error("Couldn't read the photo: \(error)")
                session.preview = .failed
            }
        }
    }

    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        guard let input, let settings = session.editor?.settings else {
            completionHandler(nil)
            return
        }
        session.isSaving = true
        let type: UTType = format == .heic ? .heic : .jpeg
        work = Task {
            // Done can come before the photo has loaded.
            await loading?.value
            guard let original else {
                completionHandler(nil)
                return
            }
            do {
                let rendered = try await ImageComposer.render(original, filename: filename, settings: settings, format: format)
                let output = PHContentEditingOutput(contentEditingInput: input)
                try rendered.write(to: try output.renderedContentURL(for: type))
                output.adjustmentData = try PhotoEditing.adjustmentData(for: settings)
                completionHandler(output)
            } catch {
                // Photos can only be told the edit failed by getting no output.
                Self.log.error("Couldn't add the border: \(error)")
                session.isSaving = false
                completionHandler(nil)
            }
        }
    }

    func cancelContentEditing() {
        loading?.cancel()
        work?.cancel()
    }

    var shouldShowCancelConfirmation: Bool {
        session.editor.map { $0.settings != startingSettings } ?? false
    }

    @concurrent private static func read(_ url: URL) async throws -> Data {
        try Data(contentsOf: url)
    }
}
