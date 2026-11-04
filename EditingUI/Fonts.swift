//
//  Fonts.swift
//  multiborder
//

import SwiftUI

extension Font {
    /// The app's typeface. Scales with Dynamic Type relative to `.body`, like `Font.custom(_:size:)`.
    static func spaceMono(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Regular", size: size)
    }
}
