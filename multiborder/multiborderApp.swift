//
//  multiborderApp.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

@main
struct multiborderApp: App {

    init() {
        // Shown read-only on the app's page in the Settings app, which reads the App Group (see Settings.bundle/Root.plist).
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        UserDefaults.appGroup.set("\(version) (\(build))", forKey: "settingsBundleVersion")
        FeatureTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainView().environment(\.font, .spaceMono(14))
        }
    }
}

extension Font {
    /// The app's typeface. Scales with Dynamic Type relative to `.body`, like `Font.custom(_:size:)`.
    static func spaceMono(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Regular", size: size)
    }
}
