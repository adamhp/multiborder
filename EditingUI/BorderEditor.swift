//
//  BorderEditor.swift
//  multiborder
//
//  The settings the Edit page changes. The app saves them to the App Group; the Photo Editing
//  Extension keeps them with the photo instead and saves nothing.
//

import Observation
import Foundation

@MainActor @Observable final class BorderEditor {

    var settings: BorderSettings {
        didSet {
            guard settings != oldValue else { return }
            if let defaults { settings.save(to: defaults) }
            onChange?()
        }
    }

    /// Called after each real change, once it's saved.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults?

    /// - Parameter defaults: where every change is saved, or nil to save nothing.
    init(settings: BorderSettings, savingTo defaults: UserDefaults?) {
        self.settings = settings
        self.defaults = defaults
    }
}
