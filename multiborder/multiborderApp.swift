//
//  multiborderApp.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

@main
struct multiborderApp: App {
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
