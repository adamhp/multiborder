//
//  FeatureTips.swift
//  multiborder
//
//  TipKit popovers pointing out features that are easy to miss.
//

import SwiftUI
import TipKit

/// A tip that shows only while feature tips are on (see `FeatureTips.isEnabled`).
nonisolated protocol FeatureTip: Tip {}

nonisolated extension FeatureTip {
    var rules: [Rule] { [#Rule(FeatureTips.$isEnabled) { $0 }] }

    /// Under every tip, so they can all be turned off at once; the Settings tab's What's New sheet turns them back on.
    var actions: [Action] {
        [Action(id: "turnOffTips", perform: { FeatureTips.isEnabled = false }) { Text("Turn Off Tips") }]
    }
}

struct PerSideTip: FeatureTip {
    var title: Text { Text("Set each side separately") }
    var message: Text? { Text("Give every edge of the border its own width, using the sliders around the photo.") }
    var image: Image? { Image(systemName: "square.dashed") }
}

struct BlurTip: FeatureTip {
    var title: Text { Text("Blurred border") }
    var message: Text? { Text("Fill the border with a soft blur of the photo instead of a color.") }
    var image: Image? { Image(systemName: "drop.halffull") }
}

struct CornersTip: FeatureTip {
    var title: Text { Text("Rounded corners") }
    var message: Text? { Text("Round the photo’s corners, then set how much with the slider below.") }
    var image: Image? { Image(systemName: "app") }
}

struct ShadowTip: FeatureTip {
    var title: Text { Text("Shadow") }
    var message: Text? { Text("Lift the photo off the border with a soft shadow, then set its strength with the slider below.") }
    var image: Image? { Image(systemName: "shadow") }
}

struct CaptionTip: FeatureTip {
    var title: Text { Text("Camera settings caption") }
    var message: Text? { Text("Add the date, camera and exposure to the border, read from the photo.") }
    var image: Image? { Image(systemName: "text.below.photo") }
}

struct CaptionOrderTip: FeatureTip {
    var title: Text { Text("Arrange the caption") }
    var message: Text? { Text("Drag a detail to reorder it, or to move it above or below the photo. Tap one for its options.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct ClearTip: FeatureTip {
    var title: Text { Text("Hold to clear") }
    var message: Text? { Text("Hold Clear to remove every photo and start over.") }
    var image: Image? { Image(systemName: "trash") }
}

nonisolated enum FeatureTips {

    /// Whether the tips show: on unless turned off with the What's New sheet's "Show me" switch. Saved by TipKit.
    @Parameter static var isEnabled: Bool = true

    @MainActor static func configure() {
        #if DEBUG
        // Launch with -resetFeatureIntro to see the What's New sheet and every tip again.
        if ProcessInfo.processInfo.arguments.contains("-resetFeatureIntro") {
            try? Tips.resetDatastore()
            UserDefaults.appGroup.removeObject(forKey: DataModel.whatsNewVersionKey)
        }
        #endif
        try? Tips.configure()
    }

    /// `tip` while it's the one to show, otherwise nil. Tips show one at a time, in `Order`'s order, each
    /// once the one before is closed or its feature used. On iOS 17, which can't order them, none show.
    /// The Edit page's run left to right; arranging the caption comes last, as it waits for the caption to be on.
    @MainActor static func current<T: Tip>(_ tip: T) -> T? {
        if #available(iOS 18, *) {
            Order.shared.currentTip as? T
        } else {
            nil
        }
    }

    @available(iOS 18, *)
    private enum Order {
        static let shared = TipGroup(.ordered) {
            PerSideTip()
            CornersTip()
            ShadowTip()
            CaptionTip()
            BlurTip()
            ClearTip()
            CaptionOrderTip()
        }
    }
}

extension View {
    /// Shows `tip` as a popover above this view, on iOS 18 and later (see `FeatureTips.current`).
    @ViewBuilder func featureTip(_ tip: (any Tip)?) -> some View {
        if #available(iOS 26, *) {
            popoverTip(tip, arrowEdge: .bottom)
        } else if #available(iOS 18.4, *) {
            popoverTip(tip, arrowEdge: .bottom)
        } else if #available(iOS 18, *) {
            popoverTip(tip, arrowEdge: .bottom)
        } else {
            self
        }
    }
}
