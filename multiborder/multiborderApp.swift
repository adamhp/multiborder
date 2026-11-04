//
//  multiborderApp.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI
import TipKit

@main
struct multiborderApp: App {

    init() {
        // Shown read-only on the app's page in the Settings app, which reads the App Group (see Settings.bundle/Root.plist).
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        UserDefaults.appGroup.set("\(version) (\(build))", forKey: "settingsBundleVersion")
        #if DEBUG
        // Launch with -resetFeatureIntro to see the What's New sheet and every tip again.
        if ProcessInfo.processInfo.arguments.contains("-resetFeatureIntro") {
            try? Tips.resetDatastore()
            // An earlier release rather than none, so the sheet is due even on an install with no saved settings.
            UserDefaults.appGroup.set("0", forKey: DataModel.whatsNewVersionKey)
        }
        // Launch with -demoRecording for App Store and website footage: no What's New, no tips, default border settings.
        // Runs after -resetFeatureIntro so it wins when both are passed.
        let isDemoRecording = ProcessInfo.processInfo.arguments.contains("-demoRecording")
        if isDemoRecording {
            UserDefaults.appGroup.set(WhatsNew.release, forKey: DataModel.whatsNewVersionKey)
            BorderSettings().save(to: .appGroup)
        }
        #endif
        FeatureTips.configure()
        #if DEBUG
        if isDemoRecording { FeatureTips.isEnabled = false }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView().environment(\.font, .spaceMono(14))
        }
    }
}
