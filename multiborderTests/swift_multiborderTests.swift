//
//  multiborderTests.swift
//  multiborderTests
//
//  Created by Adam Pearce on 6/14/24.
//

import Foundation
import ImageIO
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
    a.aspectRatio == b.aspectRatio && a.paddingFraction == b.paddingFraction
        && a.exportWidth == b.exportWidth && isClose(a.borderColor, b.borderColor)
}

@Suite struct AspectRatioTests {

    @Test func ratios() {
        #expect(AspectRatio.allCases == [.original, .twoByThree, .threeByFour, .fourByFive, .square])
        #expect(AspectRatio.original.widthOverHeight == nil)
        #expect(AspectRatio.twoByThree.widthOverHeight == 2.0 / 3.0)
        #expect(AspectRatio.threeByFour.widthOverHeight == 0.75)
        #expect(AspectRatio.fourByFive.widthOverHeight == 0.8)
        #expect(AspectRatio.square.widthOverHeight == 1)
    }

    @Test func titles() {
        #expect(AspectRatio.allCases.map(\.title) == ["Original", "2:3", "3:4", "4:5", "1:1"])
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

    @Test(arguments: AspectRatio.allCases)
    func canvasMatchesAspectRatio(_ ratio: AspectRatio) {
        let source = CGSize(width: 3024, height: 4032)
        let layout = ImageComposer.layout(sourceSize: source, settings: BorderSettings(aspectRatio: ratio, paddingFraction: 0.05))
        let expected = ratio.widthOverHeight ?? source.width / source.height
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

    @Test func hugeCanvasIsCappedAndKeepsProportions() {
        let source = CGSize(width: 8064, height: 6048)
        let settings = BorderSettings(aspectRatio: .twoByThree, paddingFraction: BorderSettings.paddingRange.upperBound)
        let layout = ImageComposer.layout(sourceSize: source, settings: settings)
        #expect(layout.canvasSize.width * layout.canvasSize.height <= ImageComposer.maxCanvasBytes / 4 + layout.canvasSize.width)
        #expect(abs(layout.canvasSize.width / layout.canvasSize.height - 2.0 / 3.0) < 0.001)
        #expect(layout.imageRect.width < source.width)
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

    @Test func modelsWithSeparateDefaultsAreIsolated() {
        let model = DataModel(defaults: makeDefaults())
        model.settings.aspectRatio = .square
        #expect(DataModel(defaults: makeDefaults()).settings.aspectRatio == BorderSettings().aspectRatio)
    }
}

@Suite struct SaveStatusTests {

    @Test func aggregatesFailures() {
        #expect(DataModel.SaveStatus.result(failures: 0, total: 3) == .success)
        #expect(DataModel.SaveStatus.result(failures: 1, total: 1) == .failed("Couldn't save the photo"))
        #expect(DataModel.SaveStatus.result(failures: 2, total: 5) == .failed("2 of 5 photos couldn't be saved"))
    }
}

@Suite struct ImageIOTests {

    /// A solid-color Display P3 JPEG, optionally tagged with an EXIF orientation.
    private func makeJPEG(width: Int, height: Int, orientation: Int = 1) throws -> Data {
        let p3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: p3, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(colorSpace: p3, components: [1, 0, 0, 1])!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func decode(_ data: Data) throws -> (image: CGImage, type: UTType?) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image, CGImageSourceGetType(source).flatMap { UTType($0 as String) })
    }

    @Test func thumbnailIsDownsampled() async throws {
        let thumbnail = try await ImageComposer.thumbnail(from: makeJPEG(width: 400, height: 300), maxPixelSize: 100)
        #expect(thumbnail.pixelSize == CGSize(width: 400, height: 300))
        let image = try #require(thumbnail.image.cgImage)
        #expect(image.width == 100)
        #expect(image.height == 75)
    }

    @Test func thumbnailIsUpright() async throws {
        // EXIF orientation 6: stored landscape, displayed portrait.
        let thumbnail = try await ImageComposer.thumbnail(from: makeJPEG(width: 400, height: 300, orientation: 6), maxPixelSize: 100)
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
        let output = try await ImageComposer.render(makeJPEG(width: 400, height: 300), settings: settings)
        let (image, type) = try decode(output)

        let layout = ImageComposer.layout(sourceSize: CGSize(width: 400, height: 300), settings: settings)
        #expect(layout.canvasSize == CGSize(width: 500, height: 500))
        #expect(image.width == 500)
        #expect(image.height == 500)
        #expect(type == .jpeg)
        #expect(image.colorSpace?.name == CGColorSpace.displayP3)
    }

    @Test func renderDropsLocation() async throws {
        // A JPEG carrying GPS coordinates.
        let input = try makeJPEG(width: 40, height: 30)
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

    @Test func renderRespectsExportWidthAndOrientation() async throws {
        let settings = BorderSettings(aspectRatio: .fourByFive, paddingFraction: 0.05, exportWidth: 200)
        let output = try await ImageComposer.render(makeJPEG(width: 400, height: 300, orientation: 6), settings: settings)
        let source = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        // Pixels are written upright, so no orientation tag remains.
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        let (image, _) = try decode(output)
        #expect(image.width == 200)
        #expect(image.height == 250)
    }
}
