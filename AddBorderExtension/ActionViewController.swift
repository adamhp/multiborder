//
//  ActionViewController.swift
//  AddBorderExtension
//
//  "multiborder" in the share sheet's row of apps (a share extension, so it gets the app's
//  icon): borders the shared photos with the settings last used in the app and saves them
//  to the photo library.
//

import UIKit
import SwiftUI
import Photos
import UniformTypeIdentifiers
import os

/// The extension's entry point (NSExtensionPrincipalClass). Hosts `AddBorderView` and ends
/// the request when the user taps Done or Cancel.
final class ActionViewController: UIViewController {

    private var work: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // The sharing app (often light) hosts this, and SwiftUI's .preferredColorScheme can't change the
        // host's appearance from inside an extension, so set it here: otherwise primary-coloured text and
        // icons turn black on the dark background.
        overrideUserInterfaceStyle = .dark
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        let run = AddBorderRun(providers: providers)
        let host = UIHostingController(rootView: AddBorderView(
            run: run,
            proceed: { [weak self] dontShowAgain in
                // Stops counting file sizes for the intro.
                self?.work?.cancel()
                self?.work = Task { await run.proceed(dontShowAgain: dontShowAgain) }
            },
            done: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) },
            cancel: { [weak self] in
                self?.work?.cancel()
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            }
        ))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        work = Task { await run.start() }
    }
}

/// Renders and saves the shared photos one at a time, which keeps memory to one canvas.
@MainActor @Observable final class AddBorderRun {

    enum State: Equatable {
        /// Asks before saving, saying what the extension does differently from the app,
        /// unless the user turned this off with "Don't show this again".
        case intro
        case working(done: Int, total: Int)
        case finished(saved: Int, total: Int)
        case failed(String)
    }

    private(set) var state: State
    /// The settings last used in the app, which every photo is bordered with.
    let settings = BorderSettings.load(from: .appGroup)
    /// Combined file size of the shared photos, filled in while the intro shows.
    private(set) var totalBytes: Int64?
    private let providers: [NSItemProvider]
    private static let log = Logger(subsystem: "com.adamhp.multiborder", category: "AddBorderExtension")

    init(providers: [NSItemProvider]) {
        self.providers = providers
        state = .intro
    }

    var photoCount: Int { providers.count }

    /// Shared by both extensions through the App Group.
    private static let skipsIntroKey = shareExtensionSkipsIntroKey

    /// Shows the intro, or, if the user asked not to see it again, shows the settings summary
    /// for a moment and then saves.
    func start() async {
        guard !providers.isEmpty else {
            state = .failed(String(localized: "There are no photos to add a border to."))
            return
        }
        guard UserDefaults.appGroup.bool(forKey: Self.skipsIntroKey) else {
            await countBytes()
            return
        }
        state = .working(done: 0, total: providers.count)
        async let counted: Void = countBytes()
        // Long enough to read which settings are about to be used.
        try? await Task.sleep(for: .seconds(1.5))
        if !Task.isCancelled {
            await save()
        }
        await counted
    }

    /// Fills in `totalBytes` for the settings summary.
    private func countBytes() async {
        var total: Int64 = 0
        for provider in providers {
            guard let size = await Self.fileSize(of: provider), !Task.isCancelled else { return }
            total += size
        }
        totalBytes = total
    }

    /// Continue on the intro.
    func proceed(dontShowAgain: Bool) async {
        if dontShowAgain {
            UserDefaults.appGroup.set(true, forKey: Self.skipsIntroKey)
        }
        await save()
    }

    private func save() async {
        state = .working(done: 0, total: providers.count)
        guard await PhotoLibrary.requestAccess(album: settings.savesToAlbum) else {
            state = .failed(String(localized: "Allow multiborder to add photos in Settings to save them."))
            return
        }
        var saved = 0
        for (index, provider) in providers.enumerated() {
            guard !Task.isCancelled else { return }
            do {
                let photo = try await Self.loadPhoto(from: provider)
                let output = try await ImageComposer.render(photo.data, filename: photo.filename, settings: settings)
                try await PhotoLibrary.save(output, source: photo.data, settings: settings)
                saved += 1
            } catch {
                Self.log.error("Photo \(index + 1) failed: \(error, privacy: .public)")
            }
            state = .working(done: index + 1, total: providers.count)
        }
        state = .finished(saved: saved, total: providers.count)
    }

    /// The size of the photo's file, or nil if it can't be read.
    private nonisolated static func fileSize(of provider: NSItemProvider) async -> Int64? {
        let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
            ?? UTType.image.identifier
        return await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                let size = (try? url?.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                continuation.resume(returning: size.map(Int64.init))
            }
        }
    }

    /// The photo's bytes and file name. The file is removed once the handler returns, so it's read there.
    private nonisolated static func loadPhoto(from provider: NSItemProvider) async throws -> (data: Data, filename: String) {
        let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
            ?? UTType.image.identifier
        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                if let url, let data = try? Data(contentsOf: url) {
                    continuation.resume(returning: (data, url.lastPathComponent))
                } else {
                    continuation.resume(throwing: error ?? ImageComposer.ComposeError.unreadable)
                }
            }
        }
    }
}

struct AddBorderView: View {

    let run: AddBorderRun
    let proceed: (_ dontShowAgain: Bool) -> Void
    let done: () -> Void
    let cancel: () -> Void
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            switch run.state {
            case .intro:
                Text("Add borders with your last settings?")
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 16) {
                    Label("Uses the settings you last used in multiborder.", systemImage: "slider.horizontal.3")
                    Label("Saves at up to about 10 MP. Use Download in the app for full resolution.",
                          systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .font(.custom("SpaceMono-Regular", size: 14))
                .foregroundStyle(.secondary)
                SettingsSummary(run: run)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Don't show this again", isOn: $dontShowAgain)
                    Text("Turn it back on in multiborder's Settings tab.")
                        .font(.custom("SpaceMono-Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
                .font(.custom("SpaceMono-Regular", size: 14))
                Spacer()
                HStack(spacing: 16) {
                    Button("Cancel", role: .cancel, action: cancel)
                    Button("Continue") { proceed(dontShowAgain) }
                        .buttonStyle(.borderedProminent)
                }
            case .working(let finished, let total):
                Text(total == 1 ? "Adding a border…" : "Adding borders…")
                ProgressView(value: Double(finished), total: Double(max(total, 1)))
                    .padding(.horizontal, 48)
                Text("\(finished) of \(total)")
                    .foregroundStyle(.secondary)
                SettingsSummary(run: run)
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
            case .finished(let saved, let total):
                Image(systemName: saved == total ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 48))
                Text(summary(saved: saved, total: total))
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Done", action: done)
                    .buttonStyle(.borderedProminent)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                Text(message)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Done", action: done)
                    .buttonStyle(.borderedProminent)
            }
        }
        .font(.custom("SpaceMono-Regular", size: 16))
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: run.state) { _, state in
            if case .finished(let saved, let total) = state { saved == total } else { false }
        }
    }

    private func summary(saved: Int, total: Int) -> String {
        if saved == total {
            total == 1 ? String(localized: "Saved the photo to your library.")
                       : String(localized: "Saved \(total) photos to your library.")
        } else {
            String(localized: "Saved \(saved) of \(total) photos. The rest couldn't be read.")
        }
    }
}

/// The settings the photos will get, as the app shows them: the ratio, the border on the
/// Border Width slider's 0–64 scale, the fill, and the download size.
private struct SettingsSummary: View {

    let run: AddBorderRun

    var body: some View {
        let settings = run.settings
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Ratio").foregroundStyle(.secondary)
                Text(settings.aspectRatio.title(landscape: settings.isLandscape))
            }
            GridRow {
                Text("Border").foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(border(settings))
                    if settings.fill == .blur {
                        Text("blurred photo")
                    } else {
                        Circle()
                            .fill(Color(settings.borderColor))
                            .overlay(Circle().stroke(.secondary, lineWidth: 1))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            GridRow {
                Text("Size").foregroundStyle(.secondary)
                Text(settings.exportWidth == 0 ? "Original, up to ~10 MP" : "\(settings.exportWidth)px wide, up to ~10 MP")
            }
            GridRow {
                Text("Saves").foregroundStyle(.secondary)
                Text(saving(settings))
            }
            GridRow {
                Text("Photos").foregroundStyle(.secondary)
                if let bytes = run.totalBytes {
                    Text("\(run.photoCount), \(bytes.formatted(.byteCount(style: .file)))")
                } else {
                    Text("\(run.photoCount), counting size…")
                }
            }
        }
        .font(.custom("SpaceMono-Regular", size: 14))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
    }

    /// The format, and HDR, the album and date when they're on, e.g. "HEIC, HDR, in multiborder, original date".
    private func saving(_ settings: BorderSettings) -> String {
        var parts = [settings.exportFormat == .original ? String(localized: "Original format") : settings.exportFormat.title]
        if #available(iOS 18, *), settings.savesHDR { parts.append(String(localized: "HDR")) }
        if settings.savesToAlbum { parts.append(String(localized: "in \(settings.albumName)")) }
        if settings.keepsOriginalDate { parts.append(String(localized: "original date")) }
        return parts.joined(separator: ", ")
    }

    /// The width on the Border Width slider's 0–64 scale, or each side's when they differ.
    private func border(_ settings: BorderSettings) -> String {
        let scale = 64 / BorderSettings.paddingRange.upperBound
        func value(_ fraction: Double) -> Int { Int((fraction * scale).rounded()) }
        if settings.isPerSide, let sides = settings.sides {
            return "T \(value(sides.top)) R \(value(sides.right)) B \(value(sides.bottom)) L \(value(sides.left))"
        }
        return "\(value(settings.paddingFraction))"
    }
}
