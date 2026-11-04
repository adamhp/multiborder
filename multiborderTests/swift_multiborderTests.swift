//
//  multiborderTests.swift
//  multiborderTests
//
//  Created by Adam Pearce on 6/14/24.
//

import AppIntents
import CoreText
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import multiborder

/// Color.Resolved stores linear components but encodes gamma-encoded ones, so a
/// round trip can drift by a float ulp; compare with a tolerance instead of `==`.
private func isClose(_ a: Color.Resolved, _ b: Color.Resolved) -> Bool {
    [a.red - b.red, a.green - b.green, a.blue - b.blue, a.opacity - b.opacity].allSatisfy { abs($0) < 0.0001 }
}

private func isClose(_ a: BorderSettings, _ b: BorderSettings) -> Bool {
    a.aspectRatio == b.aspectRatio && a.isLandscape == b.isLandscape && a.paddingFraction == b.paddingFraction
        && a.isPerSide == b.isPerSide && a.sides == b.sides
        && a.exportWidth == b.exportWidth && a.fill == b.fill && a.blurFraction == b.blurFraction
        && a.showsCaption == b.showsCaption && a.captionFields == b.captionFields
        && a.captionAbove == b.captionAbove && a.captionBelow == b.captionBelow
        && a.handle == b.handle && a.handleStyle == b.handleStyle
        && a.captionHiddenIcons == b.captionHiddenIcons && a.cameraShowsMake == b.cameraShowsMake && a.cameraShowsModel == b.cameraShowsModel
        && a.captionAlignmentAbove == b.captionAlignmentAbove && a.captionAlignmentBelow == b.captionAlignmentBelow
        && a.captionFont == b.captionFont && a.showsCaptionIcons == b.showsCaptionIcons && isClose(a.borderColor, b.borderColor)
        && a.roundsCorners == b.roundsCorners && a.cornerFraction == b.cornerFraction
        && a.hasShadow == b.hasShadow && a.shadowFraction == b.shadowFraction && a.exportFormat == b.exportFormat
        && a.savesToAlbum == b.savesToAlbum && a.albumName == b.albumName && a.albumID == b.albumID
        && a.keepsOriginalDate == b.keepsOriginalDate
}

@Suite struct AspectRatioTests {

    @Test func ratios() {
        #expect(AspectRatio.allCases == [.original, .twoByThree, .threeByFour, .fourByFive, .square, .nineBySixteen])
        #expect(AspectRatio.original.widthOverHeight == nil)
        #expect(AspectRatio.twoByThree.widthOverHeight == 2.0 / 3.0)
        #expect(AspectRatio.threeByFour.widthOverHeight == 0.75)
        #expect(AspectRatio.fourByFive.widthOverHeight == 0.8)
        #expect(AspectRatio.square.widthOverHeight == 1)
        #expect(AspectRatio.nineBySixteen.widthOverHeight == 9.0 / 16.0)
    }

    @Test func titles() {
        #expect(AspectRatio.allCases.map { $0.title(landscape: false) } == ["Original", "2:3", "3:4", "4:5", "1:1", "9:16"])
        #expect(AspectRatio.allCases.map { $0.title(landscape: true) } == ["Original", "3:2", "4:3", "5:4", "1:1", "16:9"])
    }

    @Test func landscapeTurnsTheCanvasSideways() {
        #expect(BorderSettings(aspectRatio: .fourByFive, isLandscape: true).canvasWidthOverHeight == 1.25)
        #expect(BorderSettings(aspectRatio: .fourByFive).canvasWidthOverHeight == 0.8)
        #expect(BorderSettings(aspectRatio: .original, isLandscape: true).canvasWidthOverHeight == nil)
        #expect(BorderSettings(aspectRatio: .square, isLandscape: true).canvasWidthOverHeight == 1)
    }
}

@Suite struct LayoutTests {

    @Test func noPaddingOriginalRatioIsTheSourceSize() {
        let settings = BorderSettings(aspectRatio: .original, paddingFraction: 0)
        let layout = ImageComposer.layout(sourceSize: CGSize(width: 3000, height: 2000), settings: settings)
        #expect(layout.canvasSize == CGSize(width: 3000, height: 2000))
        #expect(layout.imageRect == CGRect(x: 0, y: 0, width: 3000, height: 2000))
    }

    @Test func photoIsNeverUpscaled() {
        let settings = BorderSettings(aspectRatio: .square, paddingFraction: 0, exportWidth: 8192)
        let layout = ImageComposer.layout(sourceSize: CGSize(width: 1000, height: 500), settings: settings)
        #expect(layout.canvasSize == CGSize(width: 1000, height: 1000))
        #expect(layout.imageRect.size == CGSize(width: 1000, height: 500))
    }

    @Test func exportWidthShrinksCanvasAndKeepsProportions() {
        let settings = BorderSettings(aspectRatio: .fourByFive, paddingFraction: 0.1, exportWidth: 1080)
        let layout = ImageComposer.layout(sourceSize: CGSize(width: 4000, height: 3000), settings: settings)
        #expect(layout.canvasSize == CGSize(width: 1080, height: 1350))
        // 10% of the 1080px shorter side on the left and right.
        #expect(abs(layout.imageRect.minX - 108) < 0.5)
        #expect(abs(layout.imageRect.width - 864) < 0.5)
        #expect(abs(layout.imageRect.midY - 675) < 0.5)
    }

    @Test(arguments: AspectRatio.allCases, [false, true])
    func canvasMatchesAspectRatio(_ ratio: AspectRatio, landscape: Bool) {
        let source = CGSize(width: 3024, height: 4032)
        let settings = BorderSettings(aspectRatio: ratio, isLandscape: landscape, paddingFraction: 0.05)
        let layout = ImageComposer.layout(sourceSize: source, settings: settings)
        let expected = settings.canvasWidthOverHeight ?? source.width / source.height
        #expect(abs(layout.canvasSize.width / layout.canvasSize.height - expected) < 0.01)
        #expect(layout.imageRect.width <= source.width + 0.5)
        #expect(layout.imageRect.height <= source.height + 0.5)
        // The photo stays centered (to the nearest whole pixel) and keeps its own proportions.
        #expect(abs(layout.imageRect.midX - layout.canvasSize.width / 2) <= 0.5)
        #expect(abs(layout.imageRect.midY - layout.canvasSize.height / 2) <= 0.5)
        #expect(abs(layout.imageRect.width / layout.imageRect.height - source.width / source.height) < 0.001)
    }

    @Test(arguments: AspectRatio.allCases)
    func paddingIsAFractionOfTheShorterSide(_ ratio: AspectRatio) {
        let fraction = 0.1
        let source = CGSize(width: 1000, height: 1000)
        let layout = ImageComposer.layout(sourceSize: source, settings: BorderSettings(aspectRatio: ratio, paddingFraction: fraction))
        let inset = fraction * min(layout.canvasSize.width, layout.canvasSize.height)
        // A square photo touches the padding on the canvas's shorter side.
        let gap = min(layout.imageRect.minX, layout.imageRect.minY)
        #expect(abs(gap - inset) < 1)
        #expect(layout.imageRect.size == source)
    }

    @Test func paddingScalesWithExportWidth() {
        let source = CGSize(width: 4000, height: 3000)
        let full = ImageComposer.layout(sourceSize: source, settings: BorderSettings(aspectRatio: .square, paddingFraction: 0.08))
        let small = ImageComposer.layout(sourceSize: source, settings: BorderSettings(aspectRatio: .square, paddingFraction: 0.08, exportWidth: 1000))
        #expect(small.canvasSize == CGSize(width: 1000, height: 1000))
        let scale = small.canvasSize.width / full.canvasSize.width
        #expect(abs(small.imageRect.minX - full.imageRect.minX * scale) < 1)
        #expect(abs(small.imageRect.width - full.imageRect.width * scale) < 1)
    }

    /// At full resolution every slider step must copy the photo pixel for pixel:
    /// integral canvas and origin, scale exactly 1, and the border at least the requested width.
    @Test(arguments: AspectRatio.allCases)
    func nativeExportIsPixelAligned(_ ratio: AspectRatio) {
        let source = CGSize(width: 4032, height: 3024)
        for step in 0...64 {
            let fraction = BorderSettings.paddingRange.upperBound * Double(step) / 64
            let layout = ImageComposer.layout(sourceSize: source, settings: BorderSettings(aspectRatio: ratio, paddingFraction: fraction))
            #expect(layout.imageRect.size == source)
            #expect(layout.imageRect.minX == layout.imageRect.minX.rounded())
            #expect(layout.imageRect.minY == layout.imageRect.minY.rounded())
            #expect(layout.canvasSize.width == layout.canvasSize.width.rounded())
            #expect(layout.canvasSize.height == layout.canvasSize.height.rounded())
            let inset = (fraction * min(layout.canvasSize.width, layout.canvasSize.height)).rounded()
            #expect(min(layout.imageRect.minX, layout.imageRect.minY) >= inset)
        }
    }

    @Test func equalSidesMatchTheSingleWidth() {
        let source = CGSize(width: 4032, height: 3024)
        for exportWidth in [0, 1080] {
            let single = BorderSettings(aspectRatio: .fourByFive, paddingFraction: 0.1, exportWidth: exportWidth)
            var perSide = single
            perSide.paddingFraction = 0
            perSide.isPerSide = true
            perSide.sides = BorderInsets(uniform: 0.1)
            #expect(ImageComposer.layout(sourceSize: source, settings: perSide) == ImageComposer.layout(sourceSize: source, settings: single))
        }
    }

    @Test func sidesAreIgnoredWhileOff() {
        let source = CGSize(width: 4032, height: 3024)
        let single = BorderSettings(aspectRatio: .square, paddingFraction: 0.05)
        var withSides = single
        withSides.sides = BorderInsets(top: 0, left: 0.1, bottom: 0.16, right: 0)
        #expect(ImageComposer.layout(sourceSize: source, settings: withSides) == ImageComposer.layout(sourceSize: source, settings: single))
    }

    /// Native and capped exports: each side is at least its width, and the photo is centered between the borders.
    @Test(arguments: [0, 1080])
    func unevenSidesKeepEachWidthAndCenterBetweenThem(exportWidth: Int) {
        let source = CGSize(width: 3024, height: 4032)
        let insets = BorderInsets(top: 0.02, left: 0.04, bottom: 0.16, right: 0.08)
        let settings = BorderSettings(aspectRatio: .square, paddingFraction: 0, isPerSide: true, sides: insets, exportWidth: exportWidth)
        let layout = ImageComposer.layout(sourceSize: source, settings: settings)
        let canvas = layout.canvasSize, rect = layout.imageRect
        let shorter = min(canvas.width, canvas.height)
        #expect(rect.minY >= insets.top * shorter - 0.5)
        #expect(rect.minX >= insets.left * shorter - 0.5)
        #expect(canvas.height - rect.maxY >= insets.bottom * shorter - 0.5)
        #expect(canvas.width - rect.maxX >= insets.right * shorter - 0.5)
        // A portrait photo on a square canvas fills the height, so the top and bottom are their widths,
        // give or take the whole-pixel rounding of each inset and of the canvas.
        #expect(abs(rect.minY - insets.top * shorter) <= 2)
        #expect(abs(canvas.height - rect.maxY - insets.bottom * shorter) <= 2)
        // The spare width is split evenly beyond each side's own width.
        let spareLeft = rect.minX - insets.left * shorter
        let spareRight = canvas.width - rect.maxX - insets.right * shorter
        #expect(abs(spareLeft - spareRight) <= 1.5)
        #expect(abs(rect.width / rect.height - source.width / source.height) < 0.001)
    }

    @Test func hugeCanvasIsCappedAndKeepsProportions() {
        let source = CGSize(width: 8064, height: 6048)
        let settings = BorderSettings(aspectRatio: .twoByThree, paddingFraction: BorderSettings.paddingRange.upperBound)
        let layout = ImageComposer.layout(sourceSize: source, settings: settings)
        #expect(layout.canvasSize.width * layout.canvasSize.height <= ImageComposer.maxCanvasBytes / 4 + layout.canvasSize.width)
        #expect(abs(layout.canvasSize.width / layout.canvasSize.height - 2.0 / 3.0) < 0.001)
        #expect(layout.imageRect.width < source.width)
    }

    @Test func deepCanvasBudgetIsHalved() {
        #expect(ImageComposer.maxCanvasPixels(bitsPerComponent: 8) == ImageComposer.maxCanvasBytes / 4)
        #expect(ImageComposer.maxCanvasPixels(bitsPerComponent: 10) == ImageComposer.maxCanvasBytes / 8)
        #expect(ImageComposer.maxCanvasPixels(bitsPerComponent: 16) == ImageComposer.maxCanvasBytes / 8)
    }

    @Test func sixteenBitBudgetCapsCanvasBytes() {
        // 48MP photo with a wide border: well over the budget at native size.
        let source = CGSize(width: 8064, height: 6048)
        let settings = BorderSettings(aspectRatio: .square, paddingFraction: 0.16)
        let maxPixels = ImageComposer.maxCanvasPixels(bitsPerComponent: 16)
        let deep = ImageComposer.layout(sourceSize: source, settings: settings, maxPixels: maxPixels)
        // Rounding can add at most about one row and column.
        let slack = 8 * (deep.canvasSize.width + deep.canvasSize.height + 1)
        #expect(deep.canvasSize.width * deep.canvasSize.height * 8 <= ImageComposer.maxCanvasBytes + slack)
        // Same proportions as the 8-bit (preview/default) layout, only smaller.
        let shallow = ImageComposer.layout(sourceSize: source, settings: settings)
        #expect(deep.canvasSize.width < shallow.canvasSize.width)
        #expect(abs(deep.canvasSize.width / deep.canvasSize.height - shallow.canvasSize.width / shallow.canvasSize.height) < 0.01)
        #expect(abs(deep.imageRect.width / deep.canvasSize.width - shallow.imageRect.width / shallow.canvasSize.width) < 0.01)
    }

    @Test func emptySourceHasEmptyLayout() {
        let layout = ImageComposer.layout(sourceSize: .zero, settings: BorderSettings())
        #expect(layout.canvasSize == .zero)
    }
}

@Suite struct ColorPersistenceTests {

    private func roundTrip(_ color: Color.Resolved) throws -> Color.Resolved {
        try JSONDecoder().decode(Color.Resolved.self, from: JSONEncoder().encode(color))
    }

    @Test func grayscaleColorRoundTrips() throws {
        // A grayscale UIColor has two components; the old code indexed the third and crashed.
        let gray = Color(uiColor: UIColor(white: 0.3, alpha: 1)).resolve(in: EnvironmentValues())
        #expect(UIColor(white: 0.3, alpha: 1).cgColor.numberOfComponents == 2)
        let decoded = try roundTrip(gray)
        #expect(isClose(decoded, gray))
        #expect(abs(decoded.red - decoded.green) < 0.0001)
        #expect(abs(decoded.green - decoded.blue) < 0.0001)
    }

    @Test func displayP3ColorKeepsItsWideGamut() throws {
        let p3Red = Color.Resolved(colorSpace: .displayP3, red: 1, green: 0, blue: 0)
        let decoded = try roundTrip(p3Red)
        #expect(isClose(decoded, p3Red))
        // Display P3 red lies outside sRGB, so it has extended-range components.
        #expect(decoded.red > 1 || decoded.green < 0 || decoded.blue < 0)
    }
}

@Suite struct SettingsTests {

    private func makeDefaults() -> UserDefaults {
        let name = "multiborderTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func legacyAspectRatios() {
        #expect(AspectRatio(legacyValue: -1) == .original)
        #expect(AspectRatio(legacyValue: 2.0 / 3.0) == .twoByThree)
        #expect(AspectRatio(legacyValue: 0.8) == .fourByFive)
        #expect(AspectRatio(legacyValue: 1) == .square)
    }

    @Test func roundTripsThroughUserDefaults() {
        let defaults = makeDefaults()
        let p3 = Color.Resolved(colorSpace: .displayP3, red: 1, green: 0.2, blue: 0.1)
        let settings = BorderSettings(aspectRatio: .threeByFour, paddingFraction: 0.07, borderColor: p3, exportWidth: 2048)
        settings.save(to: defaults)
        #expect(isClose(BorderSettings.load(from: defaults), settings))

        let gray = Color.Resolved(red: 0.5, green: 0.5, blue: 0.5)
        var graySettings = settings
        graySettings.borderColor = gray
        graySettings.save(to: defaults)
        #expect(isClose(BorderSettings.load(from: defaults).borderColor, gray))
    }

    @Test func migratesLegacyKeys() {
        let defaults = makeDefaults()
        defaults.set(-1.0, forKey: "desiredAspectRatio")
        defaults.set(CGFloat(20), forKey: "desiredPadding")
        defaults.set(4096, forKey: "desiredSize")
        defaults.set(true, forKey: "colorStored")
        defaults.set(0.0, forKey: "colorR")
        defaults.set(0.0, forKey: "colorG")
        defaults.set(0.0, forKey: "colorB")
        let settings = BorderSettings.load(from: defaults)
        #expect(settings.aspectRatio == .original)
        #expect(abs(settings.paddingFraction - 0.05) < 0.0001)
        #expect(settings.exportWidth == 4096)
        #expect(isClose(settings.borderColor, Color.Resolved(red: 0, green: 0, blue: 0)))
    }

    @Test func loadsSettingsSavedBeforeOrientationExisted() throws {
        let defaults = makeDefaults()
        var stored = BorderSettings(aspectRatio: .twoByThree, paddingFraction: 0.1, exportWidth: 1080)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        json.removeValue(forKey: "isLandscape")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "borderSettings")

        let loaded = BorderSettings.load(from: defaults)
        stored.isLandscape = false
        #expect(isClose(loaded, stored))
    }

    @Test func loadsSettingsSavedBeforePerSideBordersExisted() throws {
        let defaults = makeDefaults()
        var stored = BorderSettings(aspectRatio: .square, paddingFraction: 0.1, isPerSide: true,
                                    sides: BorderInsets(top: 0.01, left: 0.02, bottom: 0.03, right: 0.04))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        json.removeValue(forKey: "isPerSide")
        json.removeValue(forKey: "sides")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "borderSettings")
        let loaded = BorderSettings.load(from: defaults)
        #expect(!loaded.isPerSide)
        #expect(loaded.sides == nil)

        stored.save(to: defaults)
        #expect(isClose(BorderSettings.load(from: defaults), stored))
        stored.isPerSide = false
        #expect(stored.insets == BorderInsets(uniform: 0.1))
    }

    @Test func loadsSettingsSavedBeforeFillExisted() throws {
        let defaults = makeDefaults()
        let stored = BorderSettings(aspectRatio: .square, paddingFraction: 0.1, fill: .blur, blurFraction: 0.08)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        json.removeValue(forKey: "fill")
        json.removeValue(forKey: "blurFraction")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "borderSettings")
        let loaded = BorderSettings.load(from: defaults)
        #expect(loaded.fill == .color)
        #expect(loaded.blurFraction == BorderSettings().blurFraction)

        stored.save(to: defaults)
        #expect(isClose(BorderSettings.load(from: defaults), stored))
    }

    @Test func loadsSettingsSavedBeforeSaveOptionsExisted() throws {
        let defaults = makeDefaults()
        let stored = BorderSettings(aspectRatio: .square, roundsCorners: true, cornerFraction: 0.03, hasShadow: true,
                                    shadowFraction: 0.02, exportFormat: .png, savesToAlbum: true, albumName: "Trips",
                                    albumID: "ABC/L0/040", keepsOriginalDate: true, keepsHDR: false)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        for key in ["roundsCorners", "cornerFraction", "hasShadow", "shadowFraction", "exportFormat", "savesToAlbum", "albumName", "albumID",
                    "keepsOriginalDate", "keepsHDR"] {
            json.removeValue(forKey: key)
        }
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "borderSettings")
        let loaded = BorderSettings.load(from: defaults)
        #expect(loaded.aspectRatio == .square)
        #expect(!loaded.roundsCorners && !loaded.hasShadow)
        #expect(loaded.cornerFraction == BorderSettings().cornerFraction && loaded.shadowFraction == BorderSettings().shadowFraction)
        #expect(loaded.exportFormat == .original && !loaded.savesToAlbum && !loaded.keepsOriginalDate && loaded.keepsHDR)
        #expect(loaded.albumName == PhotoLibrary.defaultAlbumName && loaded.albumID == nil)

        stored.save(to: defaults)
        #expect(isClose(BorderSettings.load(from: defaults), stored))
    }

    @Test func hdrIsSavedUnlessOffOrPNG() {
        #expect(BorderSettings().savesHDR)
        #expect(BorderSettings(exportFormat: .heic).savesHDR && BorderSettings(exportFormat: .jpeg).savesHDR)
        #expect(!BorderSettings(exportFormat: .png).savesHDR)
        #expect(!BorderSettings(keepsHDR: false).savesHDR)
    }

    @Test func unknownExportFormatFallsBackToOriginal() throws {
        let defaults = makeDefaults()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(BorderSettings(aspectRatio: .square))) as? [String: Any])
        json["exportFormat"] = "webp"
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "borderSettings")
        let loaded = BorderSettings.load(from: defaults)
        #expect(loaded.exportFormat == .original)
        #expect(loaded.aspectRatio == .square)
    }

    @Test func cornerRadiusScalesWithTheShorterSideAndFitsThePhoto() {
        let canvas = CGSize(width: 1000, height: 2000)
        let photo = CGSize(width: 800, height: 600)
        #expect(BorderSettings(roundsCorners: true, cornerFraction: 0.05).cornerRadius(canvasSize: canvas, photoSize: photo) == 50)
        // Off keeps square corners, and the amount for when it's back on.
        #expect(BorderSettings(roundsCorners: false, cornerFraction: 0.05).cornerRadius(canvasSize: canvas, photoSize: photo) == 0)
        #expect(BorderSettings(hasShadow: false, shadowFraction: 0.02).shadowBlur(canvasSize: canvas) == 0)
        #expect(BorderSettings(hasShadow: true, shadowFraction: 0.02).shadowBlur(canvasSize: canvas) == 20)
        #expect(BorderSettings(roundsCorners: true, cornerFraction: 1).cornerRadius(canvasSize: canvas, photoSize: photo)
                == BorderSettings.cornerRange.upperBound * 1000)
        // Never more than half the photo's shorter side, or the corners would overlap.
        #expect(BorderSettings(roundsCorners: true, cornerFraction: 0.08).cornerRadius(canvasSize: canvas, photoSize: CGSize(width: 100, height: 60)) == 30)
    }

    @Test func blurRadiusScalesWithTheShorterSideAndIsClamped() {
        let canvas = CGSize(width: 1000, height: 2000)
        #expect(BorderSettings(blurFraction: 0.05).blurRadius(canvasSize: canvas) == 50)
        #expect(BorderSettings(blurFraction: 1).blurRadius(canvasSize: canvas) == BorderSettings.blurRange.upperBound * 1000)
        #expect(BorderSettings(blurFraction: 0).blurRadius(canvasSize: canvas) == BorderSettings.blurRange.lowerBound * 1000)
    }

    @Test func defaultsWhenNothingStored() {
        #expect(BorderSettings.load(from: makeDefaults()) == BorderSettings())
    }
}

@MainActor @Suite struct DataModelTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "multiborderTests.\(UUID().uuidString)")!
    }

    @Test func settingsPersistAcrossLaunches() {
        let defaults = makeDefaults()
        let model = DataModel(defaults: defaults)
        #expect(model.settings == BorderSettings())

        model.settings.aspectRatio = .twoByThree
        model.settings.paddingFraction = 0.12
        model.settings.exportWidth = 1080
        model.settings.borderColor = Color.Resolved(colorSpace: .displayP3, red: 0.1, green: 0.8, blue: 0.3)

        #expect(isClose(DataModel(defaults: defaults).settings, model.settings))
    }

    @Test func editorWithoutDefaultsNeverSaves() {
        let defaults = makeDefaults()
        let editor = BorderEditor(settings: BorderSettings.load(from: defaults), savingTo: nil)
        editor.settings.aspectRatio = .square
        #expect(editor.settings.aspectRatio == .square)
        #expect(BorderSettings.load(from: defaults).aspectRatio == BorderSettings().aspectRatio)
        #expect(!BorderSettings.isSaved(in: defaults))
    }

    @Test func editingThroughTheEditorSavesAndResetsTheModel() {
        let defaults = makeDefaults()
        let model = DataModel(defaults: defaults)
        model.editor.settings.aspectRatio = .square
        #expect(model.settings.aspectRatio == .square)
        #expect(DataModel(defaults: defaults).settings.aspectRatio == .square)
        #expect(model.saveStatus == .unsaved)
    }

    @Test func reviewIsRequestedAfterEnoughExportsOncePerVersion() {
        let defaults = makeDefaults()
        let model = DataModel(defaults: defaults)
        defaults.set(DataModel.exportsBeforeReview - 1, forKey: "completedExports")
        #expect(!model.isReviewRequestDue)

        defaults.set(DataModel.exportsBeforeReview, forKey: "completedExports")
        #expect(model.isReviewRequestDue)

        model.recordReviewRequest()
        #expect(!model.isReviewRequestDue)
        defaults.set(DataModel.exportsBeforeReview + 10, forKey: "completedExports")
        #expect(!DataModel(defaults: defaults).isReviewRequestDue)
    }

    @Test(arguments: [TabbedItems.edit, .export])
    func losingTheLastPhotoLeavesEditAndExport(tab: TabbedItems) {
        let model = DataModel(defaults: makeDefaults())
        model.selection = [PhotosPickerItem(itemIdentifier: "a"), PhotosPickerItem(itemIdentifier: "b")]
        model.selectedTab = tab
        model.removeCurrent()
        #expect(model.selectedTab == tab)
        model.removeCurrent()
        #expect(model.selectedTab == .select)

        model.selection = [PhotosPickerItem(itemIdentifier: "c")]
        model.selectedTab = .settings
        model.clearSelection()
        #expect(model.selectedTab == .settings)
    }

    @Test func whatsNewIsSkippedOnNewInstallsAfterTheCutoff() {
        let defaults = makeDefaults()
        let after = WhatsNew.showsEveryoneUntil
        #expect(!DataModel.isWhatsNewDue(in: defaults, now: after))
        // Settings saved later, under this release, don't make it look like an update.
        DataModel(defaults: defaults).settings.aspectRatio = .square
        #expect(!DataModel.isWhatsNewDue(in: defaults, now: after))
    }

    @Test func whatsNewShowsOnNewInstallsBeforeTheCutoff() {
        let defaults = makeDefaults()
        let before = WhatsNew.showsEveryoneUntil.addingTimeInterval(-1)
        #expect(DataModel.isWhatsNewDue(in: defaults, now: before))
        // Still due until the sheet is closed.
        #expect(DataModel.isWhatsNewDue(in: defaults, now: before))
        DataModel(defaults: defaults).recordWhatsNewSeen()
        #expect(!DataModel.isWhatsNewDue(in: defaults, now: before))
    }

    @Test(arguments: ["borderSettings", "desiredAspectRatio"])
    func whatsNewShowsOnceAfterUpdatingFromBeforeItExisted(savedKey: String) {
        let defaults = makeDefaults()
        defaults.set(1.5, forKey: savedKey)
        let model = DataModel(defaults: defaults)
        #expect(model.showsWhatsNew)
        // Still due until the sheet is closed.
        #expect(DataModel(defaults: defaults).showsWhatsNew)

        model.recordWhatsNewSeen()
        #expect(!DataModel(defaults: defaults).showsWhatsNew)
    }

    @Test func whatsNewShowsAfterAnEarlierRelease() {
        let defaults = makeDefaults()
        defaults.set("2.9", forKey: "whatsNewVersion")
        #expect(DataModel(defaults: defaults).showsWhatsNew)
        defaults.set(WhatsNew.release, forKey: "whatsNewVersion")
        #expect(!DataModel(defaults: defaults).showsWhatsNew)
    }

    @Test func modelsWithSeparateDefaultsAreIsolated() {
        let model = DataModel(defaults: makeDefaults())
        model.settings.aspectRatio = .square
        #expect(DataModel(defaults: makeDefaults()).settings.aspectRatio == BorderSettings().aspectRatio)
    }

    @Test func startExportTwiceKeepsOneExport() async throws {
        let model = DataModel(defaults: makeDefaults())
        model.startExport()
        let first = try #require(model.exportTask)
        // A second tap in the same run-loop turn must not replace the pending export.
        model.startExport()
        #expect(model.exportTask == first)

        await first.value
        // The finished export clears itself so a later Download can start again.
        #expect(model.exportTask == nil)
        #expect(model.saveStatus == .unsaved)

        model.startExport()
        let second = try #require(model.exportTask)
        #expect(second != first)
        await second.value
        #expect(model.exportTask == nil)
    }

    @Test func removeCurrentKeepsSelectionInSync() {
        let model = DataModel(defaults: makeDefaults())
        let items = ["a", "b", "c"].map { PhotosPickerItem(itemIdentifier: $0) }
        model.selection = items
        #expect(model.attachments.map(\.id) == ["a", "b", "c"])
        #expect(model.selection == items)

        let remaining = [model.attachments[0], model.attachments[2]]
        model.currentIndex = 1
        model.removeCurrent()
        #expect(model.selection == [items[0], items[2]])
        #expect(model.attachments.map(\.id) == ["a", "c"])
        // The remaining attachments are the same objects, so their loaded thumbnails survive.
        let sameObjects = model.attachments.elementsEqual(remaining, by: ===)
        #expect(sameObjects)
        #expect(model.currentIndex == 0)
    }

    @Test func removingTheLastPhotoClearsTheSelection() {
        let model = DataModel(defaults: makeDefaults())
        model.selection = [PhotosPickerItem(itemIdentifier: "only")]
        model.removeCurrent()
        #expect(model.selection.isEmpty)
        #expect(model.attachments.isEmpty)
        #expect(model.currentIndex == 0)
        #expect(model.saveStatus == .unsaved)
    }

    @Test func settingSelectionRebuildsAttachments() {
        let model = DataModel(defaults: makeDefaults())
        model.selection = [PhotosPickerItem(itemIdentifier: "x")]
        let before = model.attachments
        model.selection = [PhotosPickerItem(itemIdentifier: "x"), PhotosPickerItem(itemIdentifier: "y")]
        #expect(model.attachments.map(\.id) == ["x", "y"])
        #expect(model.attachments.first !== before.first)
        model.clearSelection()
        #expect(model.selection.isEmpty)
        #expect(model.attachments.isEmpty)
    }
}

@Suite struct SaveStatusTests {

    @Test func aggregatesFailures() {
        #expect(DataModel.SaveStatus.result(failures: 0, total: 3) == .success)
        #expect(DataModel.SaveStatus.result(failures: 1, total: 1) == .failed("Couldn't save the photo"))
        #expect(DataModel.SaveStatus.result(failures: 2, total: 5) == .failed("2 of 5 photos couldn't be saved"))
    }
}

/// Finds the test bundle's resources.
nonisolated private final class TestBundle {}

/// Whether this ImageIO applies gain maps. The Simulator's doesn't (it drops their metadata and decodes HDR
/// photos as SDR), so exports there fall back to SDR, and the HDR tests only run on a device.
nonisolated private let readsGainMaps: Bool = {
    guard #available(iOS 18, *),
          let url = Bundle(for: TestBundle.self).url(forResource: "hdr-gradient", withExtension: "jpg"),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR] as CFDictionary)
    else { return false }
    return image.contentHeadroom > 1
}()

@Suite struct PhotoEditingTests {

    @Test func settingsRoundTripThroughAdjustmentData() throws {
        var settings = BorderSettings()
        settings.aspectRatio = .square
        settings.isPerSide = true
        settings.sides = BorderInsets(uniform: 0.07)
        let data = try PhotoEditing.adjustmentData(for: settings)
        #expect(data.formatIdentifier == "com.adamhp.multiborder.border")
        #expect(data.formatVersion == "1")
        #expect(PhotoEditing.canHandle(data))
        #expect(PhotoEditing.settings(from: data) == settings)
    }

    @Test func otherAdjustmentsAreNotOurs() {
        let other = PHAdjustmentData(formatIdentifier: "com.apple.photo", formatVersion: "1", data: Data())
        let future = PHAdjustmentData(formatIdentifier: PhotoEditing.formatIdentifier, formatVersion: "2", data: Data())
        let garbled = PHAdjustmentData(formatIdentifier: PhotoEditing.formatIdentifier, formatVersion: "1", data: Data("x".utf8))
        #expect(!PhotoEditing.canHandle(other))
        #expect(!PhotoEditing.canHandle(future))
        #expect(PhotoEditing.settings(from: other) == nil)
        #expect(PhotoEditing.settings(from: future) == nil)
        #expect(PhotoEditing.settings(from: garbled) == nil)
        #expect(PhotoEditing.settings(from: nil) == nil)
    }

    @Test func editingIgnoresTheAppsExportWidthAndFormat() {
        var app = BorderSettings()
        app.exportWidth = 1080
        app.exportFormat = .png
        let editing = PhotoEditing.editingSettings(app, format: PhotoEditing.outputFormat(defaultType: .heic))
        #expect(editing.exportWidth == 0)
        #expect(editing.exportFormat == .heic)
        #expect(editing.aspectRatio == app.aspectRatio)
        #expect(PhotoEditing.outputFormat(defaultType: .jpeg) == .jpeg)
        #expect(PhotoEditing.outputFormat(defaultType: nil) == .jpeg)
    }

    @Test func onlyTheShareSheetGetsTheSmallCanvas() {
        func ext(_ point: String) -> [String: Any] { ["NSExtension": ["NSExtensionPointIdentifier": point]] }
        #expect(!ImageComposer.usesSmallCanvas(nil))
        #expect(!ImageComposer.usesSmallCanvas([:]))
        #expect(ImageComposer.usesSmallCanvas(ext("com.apple.share-services")))
        #expect(ImageComposer.usesSmallCanvas(ext("com.apple.ui-services")))
        #expect(!ImageComposer.usesSmallCanvas(ext("com.apple.photo-editing")))
    }
}

@Suite struct ImageIOTests {

    /// A solid-color Display P3 image (JPEG unless `type` says otherwise), optionally tagged with an EXIF orientation.
    private func makeImage(width: Int, height: Int, orientation: Int = 1, type: UTType = .jpeg,
                           metadata: [CFString: Any] = [:]) throws -> Data {
        let p3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: p3, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(colorSpace: p3, components: [1, 0, 0, 1])!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
        let properties = metadata.merging([kCGImagePropertyOrientation: orientation]) { $1 }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    /// A 400×300 gray gradient from black at the left edge to 4× SDR white at the right, as a JPEG with an ISO gain map
    /// stored upright or with EXIF orientation 6. Made on a Mac by `scripts/make-hdr-fixtures.swift`, since the
    /// Simulator can't encode gain maps.
    private func hdrPhoto(orientation: Int = 1) throws -> Data {
        let name = orientation == 1 ? "hdr-gradient" : "hdr-gradient-orientation\(orientation)"
        let url = try #require(Bundle(for: TestBundle.self).url(forResource: name, withExtension: "jpg"))
        return try Data(contentsOf: url)
    }

    @Test func fullSizeRenderOfARotatedPhotoIsUpright() async throws {
        // Stored 400×300 with EXIF orientation 6, so it shows 300×400, like a portrait iPhone photo.
        let source = try makeImage(width: 400, height: 300, orientation: 6)
        let settings = PhotoEditing.editingSettings(BorderSettings(), format: .jpeg)
        let output = try await ImageComposer.render(source, settings: settings)
        let image = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        let expected = ImageComposer.layout(sourceSize: CGSize(width: 300, height: 400), settings: settings).canvasSize
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == Int(expected.width))
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == Int(expected.height))
    }

    @available(iOS 18, *)
    private func hasGainMap(_ data: Data) throws -> Bool {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeISOGainMap) != nil
    }

    /// The linear extended-sRGB red component of one pixel (top-left origin), decoded as on an SDR screen,
    /// or with `hdr` as on an HDR screen with the gain map applied in full.
    private func linearRed(of data: Data, x: Int, y: Int, hdr: Bool) throws -> Float {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let options = hdr ? [kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR] as CFDictionary : nil
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, options))
        var components = [Float](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &components, width: 1, height: 1, bitsPerComponent: 32, bytesPerRow: 16,
            space: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ))
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return components[0]
    }

    private func decode(_ data: Data) throws -> (image: CGImage, type: UTType?) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image, CGImageSourceGetType(source).flatMap { UTType($0 as String) })
    }

    /// The sRGB 8-bit components of one pixel of `image` (top-left origin).
    private func pixel(of image: CGImage, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (bytes[0], bytes[1], bytes[2])
    }

    @available(iOS 18, *) @MainActor @Test func shortcutsActionReturnsABorderedJPEGForEachPhoto() async throws {
        let intent = AddBorderIntent()
        intent.photos = [
            IntentFile(data: try makeImage(width: 40, height: 30, type: .heic), filename: "IMG_0001.HEIC"),
            IntentFile(data: try makeImage(width: 30, height: 40), filename: "IMG_0002.JPG"),
        ]
        let output = try #require(try await intent.perform().value)
        #expect(output.map(\.filename) == ["IMG_0001.jpg", "IMG_0002.jpg"])
        for file in output {
            #expect(try decode(file.data).type == .jpeg)
        }
    }

    @available(iOS 18, *) @MainActor @Test func shortcutsActionNamesAPhotoItCantRead() async throws {
        let intent = AddBorderIntent()
        intent.photos = [IntentFile(data: Data("not a photo".utf8), filename: "notes.txt")]
        await #expect(throws: UnreadablePhoto.self) { try await intent.perform() }
    }

    @Test func thumbnailIsDownsampled() async throws {
        let thumbnail = try await ImageComposer.thumbnail(from: makeImage(width: 400, height: 300), maxPixelSize: 100)
        #expect(thumbnail.pixelSize == CGSize(width: 400, height: 300))
        let image = try #require(thumbnail.image.cgImage)
        #expect(image.width == 100)
        #expect(image.height == 75)
    }

    @Test func thumbnailIsUpright() async throws {
        // EXIF orientation 6: stored landscape, displayed portrait.
        let thumbnail = try await ImageComposer.thumbnail(from: makeImage(width: 400, height: 300, orientation: 6), maxPixelSize: 100)
        #expect(thumbnail.pixelSize == CGSize(width: 300, height: 400))
        let image = try #require(thumbnail.image.cgImage)
        #expect(image.width == 75)
        #expect(image.height == 100)
    }

    @Test func unreadableDataThrows() async {
        await #expect(throws: ImageComposer.ComposeError.self) {
            try await ImageComposer.thumbnail(from: Data("not an image".utf8), maxPixelSize: 100)
        }
        await #expect(throws: ImageComposer.ComposeError.self) {
            try await ImageComposer.render(Data(), settings: BorderSettings())
        }
    }

    @Test func renderMatchesLayoutAndKeepsColorSpace() async throws {
        let settings = BorderSettings(aspectRatio: .square, paddingFraction: 0.1)
        let output = try await ImageComposer.render(makeImage(width: 400, height: 300), settings: settings)
        let (image, type) = try decode(output)

        let layout = ImageComposer.layout(sourceSize: CGSize(width: 400, height: 300), settings: settings)
        #expect(layout.canvasSize == CGSize(width: 500, height: 500))
        #expect(image.width == 500)
        #expect(image.height == 500)
        #expect(type == .jpeg)
        #expect(image.colorSpace?.name == CGColorSpace.displayP3)
    }

    @Test func blurFillUsesThePhotosColors() async throws {
        // A solid red photo on a white border setting: the blurred border should be red, not white.
        let red = try makeImage(width: 400, height: 300)
        let settings = BorderSettings(aspectRatio: .square, paddingFraction: 0.1, fill: .blur)
        let image = try decode(try await ImageComposer.render(red, settings: settings)).image
        #expect(image.width == 500 && image.height == 500)
        let corner = try pixel(of: image, x: 2, y: 2)
        #expect(corner.red > 200 && corner.green < 60 && corner.blue < 60)

        let plain = try decode(try await ImageComposer.render(red, settings: BorderSettings(aspectRatio: .square, paddingFraction: 0.1))).image
        let white = try pixel(of: plain, x: 2, y: 2)
        #expect(white.red > 240 && white.green > 240 && white.blue > 240)
    }

    @Test func captionIsDrawnAboveAndBelowThePhotoOnlyWhenOn() async throws {
        let metadata: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple", kCGImagePropertyTIFFModel: "iPhone 16 Pro"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifFNumber: 1.78, kCGImagePropertyExifExposureTime: 0.008,
                                             kCGImagePropertyExifDateTimeOriginal: "2026:11:02 14:05:09"],
        ]
        let photo = try makeImage(width: 400, height: 300, metadata: metadata)
        // White border, deep above and below to print in.
        var settings = BorderSettings(aspectRatio: .square, isPerSide: true,
                                      sides: BorderInsets(top: 0.2, left: 0.02, bottom: 0.2, right: 0.02))
        settings.handle = "@adam"
        /// Whether any pixel along the middle of `field`'s row is dark.
        func hasDarkText(_ data: Data, in field: CaptionField) throws -> Bool {
            let image = try decode(data).image
            let layout = ImageComposer.layout(sourceSize: CGSize(width: 400, height: 300), settings: settings)
            var on = settings
            on.showsCaption = true
            let rows = PhotoCaption.rows(photoItems: PhotoCaption.photoItems(from: metadata), settings: on)
            let entry = try #require(PhotoCaption.placement(of: rows, layout: layout)?.entries.first { $0.item.field == field })
            let y = Int(entry.frame.midY)
            return try stride(from: 0, to: image.width, by: 1).contains { x in try pixel(of: image, x: x, y: y).red < 128 }
        }
        let off = try await ImageComposer.render(photo, settings: settings)
        #expect(try !hasDarkText(off, in: .handle) && !hasDarkText(off, in: .camera))
        settings.showsCaption = true
        let on = try await ImageComposer.render(photo, settings: settings)
        #expect(try hasDarkText(on, in: .handle))
        #expect(try hasDarkText(on, in: .camera))
    }

    @Test func heicStaysHEICUnlessSharing() async throws {
        let heic = try makeImage(width: 40, height: 30, type: .heic)
        try #require(decode(heic).type == .heic, "HEIC encoding is unavailable here")

        let saved = try await ImageComposer.render(heic, settings: BorderSettings())
        #expect(try decode(saved).type == .heic)
        let shared = try await ImageComposer.render(heic, settings: BorderSettings(), format: .jpeg)
        #expect(try decode(shared).type == .jpeg)
    }

    @Test func exportFormatPicksTheFileType() async throws {
        let jpeg = try makeImage(width: 40, height: 30)
        let png = try makeImage(width: 40, height: 30, type: .png)
        #expect(try decode(try await ImageComposer.render(jpeg, settings: BorderSettings())).type == .jpeg)
        // Original keeps a PNG a PNG.
        #expect(try decode(try await ImageComposer.render(png, settings: BorderSettings())).type == .png)
        #expect(try decode(try await ImageComposer.render(jpeg, settings: BorderSettings(exportFormat: .png))).type == .png)
        #expect(try decode(try await ImageComposer.render(png, settings: BorderSettings(exportFormat: .jpeg))).type == .jpeg)
        // Sharing asks for JPEG whatever the setting.
        #expect(try decode(try await ImageComposer.render(jpeg, settings: BorderSettings(exportFormat: .png), format: .jpeg)).type == .jpeg)
        let heic = try await ImageComposer.render(jpeg, settings: BorderSettings(exportFormat: .heic))
        #expect(try [UTType.heic, .jpeg].contains(decode(heic).type))
    }

    // A 400×300 photo on a square canvas with a 0.1 border: 500×500, the photo at (50, 100).
    @available(iOS 18, *)
    @Test(.enabled(if: readsGainMaps, "This ImageIO doesn't apply gain maps"), arguments: [ExportFormat.jpeg, .heic])
    func hdrPhotoKeepsItsHighlightsWhileTheBorderStaysSDR(format: ExportFormat) async throws {
        let photo = try hdrPhoto()
        let output = try await ImageComposer.render(photo, settings: BorderSettings(aspectRatio: .square, paddingFraction: 0.1,
                                                                                    exportFormat: format))
        try #require(decode(output).type == (format == .heic ? .heic : .jpeg), "\(format) encoding is unavailable here")
        #expect(try hasGainMap(output))
        #expect(try decode(output).image.width == 500)
        // The white border is SDR white on both kinds of screen.
        #expect(abs(try linearRed(of: output, x: 10, y: 10, hdr: false) - 1) < 0.02)
        #expect(abs(try linearRed(of: output, x: 10, y: 10, hdr: true) - 1) < 0.02)
        // The bright end of the photo goes past SDR white only on an HDR screen; the dark end stays dark.
        #expect(try linearRed(of: output, x: 440, y: 250, hdr: false) <= 1.01)
        #expect(try linearRed(of: output, x: 440, y: 250, hdr: true) > 2.5)
        #expect(try linearRed(of: output, x: 60, y: 250, hdr: true) < 0.2)
    }

    @available(iOS 18, *)
    @Test(.enabled(if: readsGainMaps, "This ImageIO doesn't apply gain maps"))
    func hdrGainMapIsTurnedUprightWithThePhoto() async throws {
        // EXIF orientation 6 turns the stored left-to-right gradient into top-to-bottom: on a square canvas
        // the 300×400 photo sits at (100, 50), bright along its bottom edge from left to right.
        let photo = try hdrPhoto(orientation: 6)
        let output = try await ImageComposer.render(photo, settings: BorderSettings(aspectRatio: .square, paddingFraction: 0.1))
        #expect(try linearRed(of: output, x: 110, y: 440, hdr: true) > 2.5)
        #expect(try linearRed(of: output, x: 390, y: 440, hdr: true) > 2.5)
        #expect(try linearRed(of: output, x: 250, y: 60, hdr: true) < 0.2)
    }

    @available(iOS 18, *)
    @Test(.enabled(if: readsGainMaps, "This ImageIO doesn't apply gain maps"))
    func roundedCornersOfAnHDRPhotoShowSDRBorder() async throws {
        let photo = try hdrPhoto()
        let settings = BorderSettings(aspectRatio: .square, paddingFraction: 0.1, roundsCorners: true, cornerFraction: 0.08)
        let output = try await ImageComposer.render(photo, settings: settings)
        // The photo's bright top-right corner pixel is cut away by the 40px radius, leaving white border unboosted.
        #expect(abs(try linearRed(of: output, x: 449, y: 100, hdr: true) - 1) < 0.02)
        #expect(try linearRed(of: output, x: 440, y: 250, hdr: true) > 2.5)
    }

    @available(iOS 18, *)
    @Test(.enabled(if: readsGainMaps, "This ImageIO doesn't apply gain maps"))
    func hdrIsDroppedWhenOffOrSavingPNG() async throws {
        let photo = try hdrPhoto()
        #expect(try !hasGainMap(try await ImageComposer.render(photo, settings: BorderSettings(keepsHDR: false))))
        let png = try await ImageComposer.render(photo, settings: BorderSettings(exportFormat: .png))
        #expect(try decode(png).type == .png && !hasGainMap(png))
        // An SDR photo stays SDR.
        #expect(try !hasGainMap(try await ImageComposer.render(makeImage(width: 40, height: 30), settings: BorderSettings())))
    }

    @available(iOS 18, *)
    @Test(.enabled(if: readsGainMaps, "This ImageIO doesn't apply gain maps"))
    func thumbnailHasAnHDRVersionOnlyForHDRPhotos() async throws {
        let photo = try hdrPhoto()
        let hdr = try await ImageComposer.thumbnail(from: photo, maxPixelSize: 100)
        let image = try #require(hdr.hdrImage)
        #expect(image.isHighDynamicRange)
        #expect(image.cgImage?.width == 100)
        #expect(try await ImageComposer.thumbnail(from: makeImage(width: 40, height: 30), maxPixelSize: 100).hdrImage == nil)
    }

    @Test func roundedCornersShowTheBorder() async throws {
        // A red photo on a white border: the photo's corner pixel is white once rounded.
        let red = try makeImage(width: 400, height: 300)
        var settings = BorderSettings(aspectRatio: .square, paddingFraction: 0.1, exportFormat: .png)
        let layout = ImageComposer.layout(sourceSize: CGSize(width: 400, height: 300), settings: settings)
        let corner = (x: Int(layout.imageRect.minX) + 1, y: Int(layout.imageRect.minY) + 1)
        let middle = (x: Int(layout.imageRect.midX), y: Int(layout.imageRect.minY) + 1)

        let square = try decode(try await ImageComposer.render(red, settings: settings)).image
        #expect(try pixel(of: square, x: corner.x, y: corner.y).green < 60)

        settings.roundsCorners = true
        settings.cornerFraction = 0.05
        let rounded = try decode(try await ImageComposer.render(red, settings: settings)).image
        #expect(try pixel(of: rounded, x: corner.x, y: corner.y).green > 240)
        #expect(try pixel(of: rounded, x: middle.x, y: middle.y).green < 60)
    }

    @Test func shadowDarkensTheBorderBelowThePhoto() async throws {
        let red = try makeImage(width: 400, height: 300)
        var settings = BorderSettings(aspectRatio: .square, paddingFraction: 0.1, exportFormat: .png)
        let layout = ImageComposer.layout(sourceSize: CGSize(width: 400, height: 300), settings: settings)
        let below = (x: Int(layout.imageRect.midX), y: Int(layout.imageRect.maxY) + 4)
        let farCorner = (x: 2, y: 2)

        let plain = try decode(try await ImageComposer.render(red, settings: settings)).image
        #expect(try pixel(of: plain, x: below.x, y: below.y).green > 240)

        settings.hasShadow = true
        settings.shadowFraction = 0.02
        let shadowed = try decode(try await ImageComposer.render(red, settings: settings)).image
        #expect(try pixel(of: shadowed, x: below.x, y: below.y).green < 230)
        // The shadow fades out well before the canvas's corner, and the photo is still drawn on top.
        #expect(try pixel(of: shadowed, x: farCorner.x, y: farCorner.y).green > 240)
        #expect(try pixel(of: shadowed, x: Int(layout.imageRect.midX), y: Int(layout.imageRect.midY)).red > 200)
    }

    @Test func captureDateUsesTheRecordedOffset() throws {
        let withOffset = try makeImage(width: 4, height: 4, metadata: [kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: "2026:11:02 14:05:09",
            kCGImagePropertyExifOffsetTimeOriginal: "+01:00",
        ]])
        #expect(PhotoLibrary.captureDate(of: withOffset) == Date(timeIntervalSince1970: 1_793_624_709))

        let local = try makeImage(width: 4, height: 4, metadata: [kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: "2026:11:02 14:05:09",
        ]])
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                         from: try #require(PhotoLibrary.captureDate(of: local)))
        #expect(components == DateComponents(year: 2026, month: 11, day: 2, hour: 14, minute: 5, second: 9))

        #expect(PhotoLibrary.captureDate(of: try makeImage(width: 4, height: 4)) == nil)
    }

    @Test func concurrentRendersAllFinish() async throws {
        let input = try makeImage(width: 40, height: 30)
        let outputs = try await withThrowingTaskGroup(of: Data.self) { group in
            for padding in [0, 0.05, 0.1, 0.15] {
                group.addTask {
                    try await ImageComposer.render(input, settings: BorderSettings(aspectRatio: .square, paddingFraction: padding))
                }
            }
            var outputs = [Data]()
            for try await output in group {
                outputs.append(output)
            }
            return outputs
        }
        #expect(outputs.count == 4)
        for output in outputs {
            let image = try decode(output).image
            #expect(image.width == image.height)
        }
    }

    @Test func renderDropsLocation() async throws {
        // A JPEG carrying GPS coordinates.
        let input = try makeImage(width: 40, height: 30)
        let source = try #require(CGImageSourceCreateWithData(input as CFData, nil))
        let tagged = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(tagged, UTType.jpeg.identifier as CFString, 1, nil))
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 37.33, kCGImagePropertyGPSLatitudeRef: "N"]
        CGImageDestinationAddImageFromSource(destination, source, 0, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let output = try await ImageComposer.render(tagged as Data, settings: BorderSettings())
        let exported = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(exported, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func renderDropsIPTCLocationButKeepsCopyright() async throws {
        let input = try makeImage(width: 40, height: 30)
        let source = try #require(CGImageSourceCreateWithData(input as CFData, nil))
        let tagged = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(tagged, UTType.jpeg.identifier as CFString, 1, nil))
        let iptc: [CFString: Any] = [
            kCGImagePropertyIPTCCity: "Cupertino",
            kCGImagePropertyIPTCProvinceState: "CA",
            kCGImagePropertyIPTCCountryPrimaryLocationName: "USA",
            kCGImagePropertyIPTCSubLocation: "Apple Park",
            kCGImagePropertyIPTCCopyrightNotice: "(c) Example",
        ]
        CGImageDestinationAddImageFromSource(destination, source, 0, [kCGImagePropertyIPTCDictionary: iptc] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        // Sanity check: the fixture really carries IPTC location.
        let taggedSource = try #require(CGImageSourceCreateWithData(tagged as CFData, nil))
        let taggedProps = try #require(CGImageSourceCopyPropertiesAtIndex(taggedSource, 0, nil) as? [CFString: Any])
        let taggedIPTC = try #require(taggedProps[kCGImagePropertyIPTCDictionary] as? [CFString: Any])
        #expect(taggedIPTC[kCGImagePropertyIPTCCity] != nil)

        let output = try await ImageComposer.render(tagged as Data, settings: BorderSettings())
        let exported = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(exported, 0, nil) as? [CFString: Any])
        let exportedIPTC = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
        #expect(exportedIPTC[kCGImagePropertyIPTCCity] == nil)
        #expect(exportedIPTC[kCGImagePropertyIPTCProvinceState] == nil)
        #expect(exportedIPTC[kCGImagePropertyIPTCCountryPrimaryLocationName] == nil)
        #expect(exportedIPTC[kCGImagePropertyIPTCSubLocation] == nil)
        #expect(exportedIPTC[kCGImagePropertyIPTCCopyrightNotice] as? String == "(c) Example")
    }

    @Test func renderRespectsExportWidthAndOrientation() async throws {
        let settings = BorderSettings(aspectRatio: .fourByFive, paddingFraction: 0.05, exportWidth: 200)
        let output = try await ImageComposer.render(makeImage(width: 400, height: 300, orientation: 6), settings: settings)
        let source = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        // Pixels are written upright, so no orientation tag remains.
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        let (image, _) = try decode(output)
        #expect(image.width == 200)
        #expect(image.height == 250)
    }
}

@Suite struct CardStackLayoutTests {

    @Test func clampedIndexStaysInRange() {
        #expect(CardStackLayout.clampedIndex(-3, count: 5) == 0)
        #expect(CardStackLayout.clampedIndex(2, count: 5) == 2)
        #expect(CardStackLayout.clampedIndex(9, count: 5) == 4)
        #expect(CardStackLayout.clampedIndex(3, count: 0) == 0)
    }

    @Test func draggingLeftMovesToLaterCards() {
        #expect(CardStackLayout.dragOffset(forTranslation: -300) == 1)
        #expect(CardStackLayout.dragOffset(forTranslation: 150) == -0.5)
    }

    @Test func visibleRangeIsAWindowAroundThePosition() {
        #expect(CardStackLayout.visibleRange(around: 0, count: 300) == 0..<8)
        #expect(CardStackLayout.visibleRange(around: 100, count: 300) == 93..<108)
        // A fractional position during a drag widens the window to cover both neighbours.
        #expect(CardStackLayout.visibleRange(around: 100.4, count: 300) == 93..<109)
        #expect(CardStackLayout.visibleRange(around: 299, count: 300) == 292..<300)
    }

    @Test func visibleRangeHandlesSmallEmptyAndOverdraggedStacks() {
        #expect(CardStackLayout.visibleRange(around: 1, count: 3) == 0..<3)
        #expect(CardStackLayout.visibleRange(around: 0, count: 0).isEmpty)
        // Dragging far past either end still renders the end cards.
        #expect(CardStackLayout.visibleRange(around: -50, count: 20) == 0..<8)
        #expect(CardStackLayout.visibleRange(around: 1e30, count: 20) == 12..<20)
        #expect(CardStackLayout.visibleRange(around: .nan, count: 20) == 0..<8)
    }

    @Test func flingMovesExactlyOneCard() {
        #expect(CardStackLayout.snapTarget(restingIndex: 2, translation: -900, predictedEndTranslation: -1200, count: 10) == 3)
        #expect(CardStackLayout.snapTarget(restingIndex: 2, translation: 50, predictedEndTranslation: 250, count: 10) == 1)
    }

    @Test func slowDragSnapsToNearestCard() {
        #expect(CardStackLayout.snapTarget(restingIndex: 2, translation: -100, predictedEndTranslation: -120, count: 10) == 2)
        #expect(CardStackLayout.snapTarget(restingIndex: 2, translation: -160, predictedEndTranslation: -180, count: 10) == 3)
        #expect(CardStackLayout.snapTarget(restingIndex: 2, translation: 0, predictedEndTranslation: 0, count: 10) == 2)
    }

    @Test func snapTargetIsClampedAtTheEnds() {
        #expect(CardStackLayout.snapTarget(restingIndex: 0, translation: 100, predictedEndTranslation: 400, count: 5) == 0)
        #expect(CardStackLayout.snapTarget(restingIndex: 4, translation: -100, predictedEndTranslation: -400, count: 5) == 4)
        #expect(CardStackLayout.snapTarget(restingIndex: 4, translation: -3000, predictedEndTranslation: -150, count: 5) == 4)
        #expect(CardStackLayout.snapTarget(restingIndex: 0, translation: 0, predictedEndTranslation: 0, count: 0) == 0)
    }
}

@Suite struct PhotoCaptionTests {

    private func properties(make: String? = nil, model: String? = nil, exif: [CFString: Any] = [:]) -> [CFString: Any] {
        var tiff = [CFString: Any]()
        tiff[kCGImagePropertyTIFFMake] = make
        tiff[kCGImagePropertyTIFFModel] = model
        return [kCGImagePropertyTIFFDictionary: tiff, kCGImagePropertyExifDictionary: exif]
    }

    private func texts(_ properties: [CFString: Any]) -> [String] {
        PhotoCaption.photoItems(from: properties).map(\.text)
    }

    private let iPhone: [CFString: Any] = [
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple", kCGImagePropertyTIFFModel: "iPhone 16 Pro"],
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifFocalLenIn35mmFilm: 24.0, kCGImagePropertyExifFocalLength: 6.765,
            kCGImagePropertyExifFNumber: 1.78, kCGImagePropertyExifExposureTime: 1.0 / 120,
            kCGImagePropertyExifISOSpeedRatings: [80], kCGImagePropertyExifDateTimeOriginal: "2026:11:02 23:30:00",
        ],
    ]

    private var captionOn: BorderSettings {
        var settings = BorderSettings()
        settings.showsCaption = true
        return settings
    }

    @Test func iPhoneDetails() throws {
        let items = PhotoCaption.photoItems(from: iPhone)
        #expect(items.map(\.field) == [.date, .camera, .focalLength, .aperture, .shutter, .iso])
        #expect(Array(items.map(\.text).dropFirst()) == ["iPhone 16 Pro", "24mm", "ƒ/1.8", "1/120s", "ISO 80"])
        // The day the camera recorded, late in the evening, isn't moved by the time zone.
        let date = items[0].text
        let expected = Date(timeIntervalSince1970: 1_793_577_600) // 2 Nov 2026, 00:00 GMT
            .formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
        #expect(date == expected)
    }

    @Test func rowsFollowTheChosenRowsOrderAndToggles() {
        var settings = captionOn
        settings.handle = "adam"
        let photo = PhotoCaption.photoItems(from: iPhone)
        var rows = PhotoCaption.rows(photoItems: photo, settings: settings)
        #expect(rows.above.map(\.field) == [.date, .handle])
        #expect(rows.below.map(\.field) == [.camera, .focalLength, .aperture, .shutter, .iso])

        settings.moveCaptionField(.iso, to: .above, at: 1)
        settings.moveCaptionField(.date, to: .below, at: 0)
        settings.captionFields.remove(.aperture)
        rows = PhotoCaption.rows(photoItems: photo, settings: settings)
        #expect(rows.above.map(\.field) == [.iso, .handle])
        #expect(rows.below.map(\.field) == [.date, .camera, .focalLength, .shutter])

        settings.showsCaption = false
        #expect(PhotoCaption.rows(photoItems: photo, settings: settings) == PhotoCaption.Rows())
    }

    @Test func iconsCanBeTurnedOffPerDetail() {
        var settings = captionOn
        settings.captionHiddenIcons = [.camera, .aperture]
        let rows = PhotoCaption.rows(photoItems: PhotoCaption.photoItems(from: iPhone), settings: settings)
        let icons = Dictionary(uniqueKeysWithValues: (rows.above + rows.below).map { ($0.field, $0.icon) })
        #expect(icons[.camera]! == nil && icons[.aperture]! == nil)
        #expect(icons[.shutter]! == .symbol("timer") && icons[.date]! == .symbol("calendar"))
        // The camera's text is still printed without its icon.
        #expect(rows.below.first { $0.field == .camera }?.text == "Apple iPhone 16 Pro")
    }

    @Test func iconsCanBeTurnedOffTogether() {
        var settings = captionOn
        settings.handle = "adam"
        settings.showsCaptionIcons = false
        let rows = PhotoCaption.rows(photoItems: PhotoCaption.photoItems(from: iPhone), settings: settings)
        #expect(!(rows.above + rows.below).isEmpty)
        #expect((rows.above + rows.below).allSatisfy { $0.icon == nil })
    }

    @Test func everyCaptionFontIsAvailableAndMeasuresDifferently() throws {
        let layout = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 1200),
                                          imageRect: CGRect(x: 50, y: 50, width: 900, height: 900))
        let items = [PhotoCaption.Item(field: .iso, text: "ISO 80")]
        for font in CaptionFont.allCases {
            // CoreText falls back to another font when the name isn't installed.
            #expect(CTFontCopyPostScriptName(font.ctFont(size: 12)) as String == font.postScriptName)
        }
        func width(_ font: CaptionFont) throws -> Double {
            try #require(PhotoCaption.placement(of: .init(below: items, font: font), layout: layout)).entries[0].frame.width
        }
        #expect(try width(.spaceMono) != width(.inter))

        var settings = BorderSettings()
        settings.showsCaption = true
        settings.captionFont = .dmSans
        #expect(PhotoCaption.rows(photoItems: [], settings: settings).font == .dmSans)
    }

    @Test func handleFollowsItsStyle() {
        var settings = captionOn
        #expect(PhotoCaption.handleItem(settings) == nil)
        settings.handle = "  @@adam "
        #expect(PhotoCaption.handleItem(settings) == .init(field: .handle, text: "adam", icon: .glyph(.instagram)))
        settings.handleStyle = .at
        #expect(PhotoCaption.handleItem(settings) == .init(field: .handle, text: "@adam"))
        #expect(PhotoCaption.handleItem(settings)?.icon == nil)
        settings.handleStyle = .website
        #expect(PhotoCaption.handleItem(settings)?.icon == .symbol("globe"))
        settings.handleStyle = .plain
        #expect(PhotoCaption.handleItem(settings) == .init(field: .handle, text: "adam"))
        #expect(PhotoCaption.handleItem(settings)?.icon == nil)
    }

    @Test func filenameIsADetailOfThePhoto() async throws {
        let items = PhotoCaption.photoItems(from: iPhone, filename: " IMG_1234.HEIC ")
        #expect(items.first { $0.field == .filename }?.text == "IMG_1234")
        #expect(PhotoCaption.photoItems(from: iPhone, filename: "").allSatisfy { $0.field != .filename })
        #expect(PhotoCaption.photoItems(from: [:], filename: ".hidden").first?.text == ".hidden")

        var settings = captionOn
        // Off until chosen: the title is usually the better label.
        #expect(!settings.captionFields.contains(.filename))
        settings.captionFields.insert(.filename)
        settings.handle = "adam"
        let rows = PhotoCaption.rows(photoItems: items, settings: settings)
        // Date at the left, filename in the middle, handle at the right.
        #expect(rows.above.map(\.field) == [.date, .filename, .handle])
    }

    private func title(_ properties: [CFString: Any], metadata: CGImageMetadata? = nil) -> String? {
        PhotoCaption.photoItems(from: properties, metadata: metadata).first { $0.field == .title }?.text
    }

    @Test func titleComesFromIPTCThenXMPThenDescriptions() throws {
        let iptc: [CFString: Any] = [kCGImagePropertyIPTCDictionary: [
            kCGImagePropertyIPTCObjectName: "Morning Fog", kCGImagePropertyIPTCCaptionAbstract: "Over the bay",
        ]]
        #expect(title(iptc) == "Morning Fog")
        #expect(title([kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCCaptionAbstract: "Over\n the   bay"]]) == "Over the bay")

        let xmp = CGImageMetadataCreateMutable()
        #expect(CGImageMetadataSetValueWithPath(xmp, nil, "dc:title" as CFString, "Harbor" as CFString))
        #expect(title([:], metadata: xmp) == "Harbor")
        #expect(title([kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFImageDescription: "Dusk"]]) == "Dusk")
    }

    @Test func titleSkipsCameraBoilerplateAndStaysShort() {
        #expect(title([kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFImageDescription: "OLYMPUS DIGITAL CAMERA"]]) == nil)
        #expect(title([kCGImagePropertyTIFFDictionary: [
            kCGImagePropertyTIFFModel: "X100V", kCGImagePropertyTIFFImageDescription: "FUJIFILM X100V",
        ]]) == nil)
        #expect(title([kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFImageDescription: "   "]]) == nil)
        let long = title([kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCObjectName: String(repeating: "a ", count: 50)]])
        #expect(long?.count == 60 && long?.hasSuffix("…") == true)
    }

    private func camera(make: String?, model: String?, showsMake: Bool = true, showsModel: Bool = true) -> String? {
        var settings = BorderSettings()
        settings.cameraShowsMake = showsMake
        settings.cameraShowsModel = showsModel
        return PhotoCaption.photoItems(from: properties(make: make, model: model))
            .first { $0.field == .camera }
            .flatMap { PhotoCaption.cameraItem($0, settings: settings) }?.text
    }

    @Test func cameraPrintsTheChosenPartsOfItsName() {
        #expect(camera(make: "FUJIFILM", model: "X-T5") == "FUJIFILM X-T5")
        #expect(camera(make: "Apple", model: "iPhone 16 Pro") == "Apple iPhone 16 Pro")
        #expect(camera(make: "Apple", model: "iPhone 16 Pro", showsMake: false) == "iPhone 16 Pro")
        #expect(camera(make: "FUJIFILM", model: "X-T5", showsModel: false) == "FUJIFILM")
        #expect(camera(make: "FUJIFILM", model: "X-T5", showsMake: false, showsModel: false) == nil)
        // A model that already names its make doesn't repeat it.
        #expect(camera(make: "Canon", model: "Canon EOS R5") == "Canon EOS R5")
        #expect(camera(make: "Canon", model: "Canon EOS R5", showsModel: false) == "Canon")
        // Only what's recorded.
        #expect(camera(make: nil, model: "X-T5", showsModel: false) == nil)
        #expect(camera(make: "Leica", model: nil) == "Leica")
    }

    @Test func longExposuresAndWholeApertures() {
        let text = texts(properties(exif: [
            kCGImagePropertyExifFocalLength: 50.0, kCGImagePropertyExifFNumber: 8.0, kCGImagePropertyExifExposureTime: 2.5,
        ]))
        #expect(text == ["50mm", "ƒ/8", "2.5s"])
    }

    @Test func nothingToPrint() {
        #expect(PhotoCaption.photoItems(from: [:]).isEmpty)
    }

    @Test func movingAFieldKeepsEveryFieldOnce() {
        var settings = BorderSettings()
        settings.moveCaptionField(.camera, to: .above, at: 99)
        settings.moveCaptionField(.handle, to: .below, at: -3)
        #expect(settings.captionAbove == [.date, .title, .filename, .camera])
        #expect(settings.captionBelow == [.handle, .focalLength, .aperture, .shutter, .iso])
    }

    @Test func savedRowsAreRepairedToListEveryFieldOnce() throws {
        let json = #"{"captionAbove": ["iso", "iso", "camera"], "captionBelow": ["camera", "date"]}"#
        let settings = try JSONDecoder().decode(BorderSettings.self, from: Data(json.utf8))
        #expect(settings.captionAbove == [.iso, .camera, .title, .filename, .handle])
        #expect(settings.captionBelow == [.date, .focalLength, .aperture, .shutter])
        let old = try JSONDecoder().decode(BorderSettings.self, from: Data("{}".utf8))
        #expect(old.captionAbove == [.date, .title, .filename, .handle] && old.captionBelow == [.camera, .focalLength, .aperture, .shutter, .iso])
        #expect(old.handle == "" && old.handleStyle == .instagram)
        #expect(old.captionFont == .spaceMono && old.showsCaptionIcons)
        let dropped = try JSONDecoder().decode(BorderSettings.self, from: Data(#"{"captionFont": "georgia", "handle": "adam"}"#.utf8))
        #expect(dropped.captionFont == .spaceMono && dropped.handle == "adam")
    }

    @Test func rowsSpreadAcrossThePhotoJustBesideIt() throws {
        let layout = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 1300),
                                          imageRect: CGRect(x: 50, y: 200, width: 900, height: 900))
        var settings = captionOn
        settings.handle = "adam"
        let rows = PhotoCaption.rows(photoItems: PhotoCaption.photoItems(from: iPhone), settings: settings)
        let placement = try #require(PhotoCaption.placement(of: rows, layout: layout))
        let above = placement.entries.filter { rows.above.contains($0.item) }.map(\.frame)
        let below = placement.entries.filter { rows.below.contains($0.item) }.map(\.frame)
        #expect(above.count == 2 && below.count == 5)
        for frames in [above, below] {
            #expect(abs(frames.first!.minX - 50) < 0.001)
            #expect(abs(frames.last!.maxX - 950) < 0.001)
            // Equal space between neighbors.
            let spaces = zip(frames, frames.dropFirst()).map { $1.minX - $0.maxX }
            #expect(spaces.allSatisfy { abs($0 - spaces[0]) < 0.001 && $0 > 0 })
        }
        // Just beside the photo, not centered in the borders.
        #expect(above[0].maxY < 200 && above[0].maxY > 200 - placement.fontSize * 1.5)
        #expect(below[0].minY > 1100 && below[0].minY < 1100 + placement.fontSize * 1.5)

        let single = try #require(PhotoCaption.placement(of: .init(below: [rows.below[4]]), layout: layout))
        #expect(abs(single.entries[0].frame.midX - 500) < 0.001)
    }

    @Test func groupedRowsSitLeftCenterOrRight() throws {
        let layout = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 1300),
                                          imageRect: CGRect(x: 50, y: 200, width: 900, height: 900))
        let items = [PhotoCaption.Item(field: .aperture, text: "ƒ/1.8"), PhotoCaption.Item(field: .iso, text: "ISO 80")]
        func frames(_ alignment: CaptionAlignment) throws -> [CGRect] {
            try #require(PhotoCaption.placement(of: .init(below: items, belowAlignment: alignment), layout: layout)).entries.map(\.frame)
        }
        let leading = try frames(.leading), center = try frames(.center), trailing = try frames(.trailing)
        #expect(abs(leading[0].minX - 50) < 0.001)
        #expect(abs((center[0].minX + center[1].maxX) / 2 - 500) < 0.001)
        #expect(abs(trailing[1].maxX - 950) < 0.001)
        // The same fixed gap in each, narrower than spreading them across the photo.
        let gaps = [leading, center, trailing].map { $0[1].minX - $0[0].maxX }
        #expect(gaps.allSatisfy { abs($0 - gaps[0]) < 0.001 })
        let spread = try frames(.spread)
        #expect(gaps[0] < spread[1].minX - spread[0].maxX)

        var settings = BorderSettings()
        settings.showsCaption = true
        settings.captionAlignmentAbove = .trailing
        let rows = PhotoCaption.rows(photoItems: [], settings: settings)
        #expect(rows.aboveAlignment == .trailing && rows.belowAlignment == .spread)
        #expect(CaptionAlignment.trailing.next == .spread)
    }

    @Test func iconsAreAsTallAsCapitalsAndStandOnTheBaseline() throws {
        let layout = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 1200),
                                          imageRect: CGRect(x: 50, y: 50, width: 900, height: 900))
        let items = [PhotoCaption.Item(field: .aperture, text: "ƒ/1.8"), PhotoCaption.Item(field: .iso, text: "ISO 80")]
        let placement = try #require(PhotoCaption.placement(of: .init(below: items), layout: layout))
        let font = CaptionFont.spaceMono.ctFont(size: placement.fontSize)
        let entry = placement.entries[0]
        let icon = placement.iconRect(for: entry)
        #expect(abs(icon.height - CTFontGetCapHeight(font)) < 0.001)
        #expect(abs(icon.maxY - placement.baseline(in: entry.frame)) < 0.001)
        #expect(abs(icon.minX - entry.frame.minX) < 0.001)
        // The camera keeps a little space under it, so it lines up with the text.
        let camera = PhotoCaption.Placement.Entry(item: .init(field: .camera, text: "X-T5"), frame: entry.frame)
        let cameraBox = placement.iconRect(for: camera)
        #expect(cameraBox.minY == icon.minY && cameraBox.maxY < icon.maxY)

        // The value starts after the icon; ISO has no icon, so its value starts at its frame.
        #expect(placement.textOffset(for: entry.item) > icon.width)
        #expect(placement.textOffset(for: placement.entries[1].item) == 0)
    }

    @Test func placementShrinksToFitAndSkipsRowsWithNoBorder() throws {
        let iso = PhotoCaption.Item(field: .iso, text: "ISO 80")
        let layout = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 1200),
                                          imageRect: CGRect(x: 50, y: 50, width: 900, height: 900))
        let short = try #require(PhotoCaption.placement(of: .init(below: [iso]), layout: layout))
        // A long line is narrowed to fit the photo's width.
        let long = try #require(PhotoCaption.placement(
            of: .init(below: [.init(field: .camera, text: String(repeating: "W", count: 80))]), layout: layout))
        #expect(long.fontSize < short.fontSize)
        #expect(long.entries[0].frame.width <= 900.001)
        // A shallow border shrinks the text to fit in it.
        let shallow = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 960),
                                           imageRect: CGRect(x: 50, y: 50, width: 900, height: 900))
        let tight = try #require(PhotoCaption.placement(of: .init(below: [iso]), layout: shallow))
        #expect(tight.entries[0].frame.maxY <= 960)

        // No border on a side: that row is left out.
        let noTop = ImageComposer.Layout(canvasSize: CGSize(width: 1000, height: 1100),
                                         imageRect: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let date = PhotoCaption.Item(field: .date, text: "Nov 2, 2026")
        let onlyBelow = try #require(PhotoCaption.placement(of: .init(above: [date], below: [iso]), layout: noTop))
        #expect(onlyBelow.entries.map(\.item) == [iso])
        #expect(PhotoCaption.placement(of: .init(above: [date]), layout: noTop) == nil)
        #expect(PhotoCaption.placement(of: .init(), layout: layout) == nil)
    }
}
