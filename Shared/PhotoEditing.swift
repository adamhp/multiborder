//
//  PhotoEditing.swift
//  multiborder
//
//  What the Photo Editing Extension tells Photos: the border's settings, saved with each edit
//  so it can be changed later, and the file type to hand back.
//

import Foundation
import Photos
import UniformTypeIdentifiers

nonisolated enum PhotoEditing {

    static let formatIdentifier = "com.adamhp.multiborder.border"
    static let formatVersion = "1"

    static func adjustmentData(for settings: BorderSettings) throws -> PHAdjustmentData {
        PHAdjustmentData(formatIdentifier: formatIdentifier, formatVersion: formatVersion,
                         data: try JSONEncoder().encode(settings))
    }

    /// Whether `data` is a border this version can redraw, so Photos hands over the original photo.
    static func canHandle(_ data: PHAdjustmentData) -> Bool {
        data.formatIdentifier == formatIdentifier && data.formatVersion == formatVersion
    }

    /// The settings saved with an earlier border, or nil if there's none this version can read.
    static func settings(from data: PHAdjustmentData?) -> BorderSettings? {
        guard let data, canHandle(data) else { return nil }
        return try? JSONDecoder().decode(BorderSettings.self, from: data.data)
    }

    /// HEIC when Photos asks for it, otherwise JPEG. Both keep an HDR photo's gain map.
    static func outputFormat(defaultType: UTType?) -> ExportFormat {
        defaultType?.conforms(to: .heic) == true ? .heic : .jpeg
    }

    /// `settings` for editing in Photos: full size, in the format Photos gets, so the preview's
    /// HDR badge agrees with the saved photo. The app's export width and format don't apply.
    static func editingSettings(_ settings: BorderSettings, format: ExportFormat) -> BorderSettings {
        var settings = settings
        settings.exportWidth = 0
        settings.exportFormat = format
        return settings
    }
}
