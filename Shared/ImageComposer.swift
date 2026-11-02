//
//  ImageComposer.swift
//  multiborder
//
//  Geometry shared by the on-screen preview and the export, plus the
//  ImageIO work (thumbnails, compositing, encoding) that runs off the main actor.
//

import SwiftUI
import ImageIO
import CoreImage
import UniformTypeIdentifiers

/// Canvas shapes, described in portrait; `BorderSettings.isLandscape` turns them sideways.
nonisolated enum AspectRatio: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case twoByThree = "2:3"
    case threeByFour = "3:4"
    case fourByFive = "4:5"
    case square = "1:1"
    case nineBySixteen = "9:16"

    var id: Self { self }

    /// Whether turning the canvas sideways changes its shape.
    var hasOrientation: Bool { self != .original && self != .square }

    /// The ratio as shown to the user, e.g. "2:3", or "3:2" in landscape.
    func title(landscape: Bool) -> String {
        guard self != .original else { return "Original" }
        guard landscape else { return rawValue }
        return rawValue.split(separator: ":").reversed().joined(separator: ":")
    }

    /// Portrait width divided by height; `nil` keeps the photo's own ratio.
    var widthOverHeight: Double? {
        switch self {
        case .original: nil
        case .twoByThree: 2.0 / 3.0
        case .threeByFour: 3.0 / 4.0
        case .fourByFive: 4.0 / 5.0
        case .square: 1.0
        case .nineBySixteen: 9.0 / 16.0
        }
    }

    /// Maps the pre-2.0.1 stored value (a ratio, or -1 for original) to a case.
    init(legacyValue: Double) {
        guard legacyValue > 0 else {
            self = .original
            return
        }
        self = Self.allCases
            .filter { $0 != .original }
            .min { abs($0.widthOverHeight! - legacyValue) < abs($1.widthOverHeight! - legacyValue) }!
    }
}

/// What fills the border around the photo.
nonisolated enum BorderFill: String, Codable, Sendable {
    /// The plain `borderColor`.
    case color
    /// The photo itself, scaled to cover the canvas and blurred.
    case blur
}

/// Border thickness of each side, as fractions of the canvas's shorter side.
nonisolated struct BorderInsets: Codable, Equatable, Sendable {
    var top: Double
    var left: Double
    var bottom: Double
    var right: Double

    init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    init(uniform value: Double) {
        self.init(top: value, left: value, bottom: value, right: value)
    }

    /// Each side limited to `range`.
    func clamped(to range: ClosedRange<Double>) -> BorderInsets {
        func clamp(_ value: Double) -> Double { min(max(value, range.lowerBound), range.upperBound) }
        return BorderInsets(top: clamp(top), left: clamp(left), bottom: clamp(bottom), right: clamp(right))
    }
}

nonisolated struct BorderSettings: Codable, Equatable, Sendable {
    static let paddingRange: ClosedRange<Double> = 0...0.16
    /// The slider shows this as 5–100 in steps of 5.
    static let blurRange: ClosedRange<Double> = 0.005...0.1

    var aspectRatio: AspectRatio = .fourByFive
    /// Turns the aspect ratio sideways (e.g. 4:5 becomes 5:4).
    var isLandscape = false
    /// Border thickness as a fraction of the canvas's shorter side.
    var paddingFraction: Double = 0
    /// Whether each side uses its own thickness from `sides` instead of `paddingFraction`.
    var isPerSide = false
    /// Per-side thicknesses, kept while `isPerSide` is off so turning it back on restores them.
    /// `nil` until per-side borders are first turned on.
    var sides: BorderInsets?
    var borderColor: Color.Resolved = Color.Resolved(red: 1, green: 1, blue: 1)
    var fill: BorderFill = .color
    /// Strength of the `.blur` fill: the Gaussian blur's standard deviation as a fraction of the
    /// canvas's shorter side, so the preview and every export size look equally soft.
    var blurFraction: Double = 0.04
    /// Whether details are printed in rows above and below the photo (see `PhotoCaption`).
    var showsCaption = false
    /// Which details the caption includes. The filename starts off; the title is usually the better label.
    var captionFields = Set(CaptionField.allCases).subtracting([.filename])
    /// The details in the row above the photo, left to right. With `captionBelow`, lists every field exactly once.
    var captionAbove = CaptionField.allCases.filter { $0.defaultRow == .above }
    /// The details in the row below the photo, left to right.
    var captionBelow = CaptionField.allCases.filter { $0.defaultRow == .below }
    /// The name printed by the `.handle` field, as typed.
    var handle = ""
    var handleStyle: HandleStyle = .instagram
    /// Details printed without their icon.
    var captionHiddenIcons = Set<CaptionField>()
    /// Which parts of the camera's name the `.camera` field prints.
    var cameraShowsMake = true
    var cameraShowsModel = true
    /// How each caption row is arranged across the photo's width.
    var captionAlignmentAbove = CaptionAlignment.spread
    var captionAlignmentBelow = CaptionAlignment.spread
    var captionFont = CaptionFont.spaceMono
    /// Whether any caption icons are printed; when on, `captionHiddenIcons` still hides single ones.
    var showsCaptionIcons = true
    /// Maximum output width in pixels; 0 exports at the photo's full resolution.
    var exportWidth: Int = 0

    /// Canvas width divided by height after orientation; `nil` keeps the photo's own ratio.
    var canvasWidthOverHeight: Double? {
        aspectRatio.widthOverHeight.map { isLandscape ? 1 / $0 : $0 }
    }

    /// The thickness of each side that the layout uses.
    var insets: BorderInsets {
        isPerSide ? sides ?? BorderInsets(uniform: paddingFraction) : BorderInsets(uniform: paddingFraction)
    }

    /// How `row` is arranged across the photo's width.
    func captionAlignment(in row: CaptionRow) -> CaptionAlignment {
        row == .above ? captionAlignmentAbove : captionAlignmentBelow
    }

    /// Every field in `row`, included or not, left to right.
    func captionOrder(in row: CaptionRow) -> [CaptionField] {
        row == .above ? captionAbove : captionBelow
    }

    /// The fields printed in `row`, left to right.
    func includedCaptionFields(in row: CaptionRow) -> [CaptionField] {
        captionOrder(in: row).filter(captionFields.contains)
    }

    /// Moves `field` to position `index` of `row`, taking it out of wherever it was.
    mutating func moveCaptionField(_ field: CaptionField, to row: CaptionRow, at index: Int) {
        captionAbove.removeAll { $0 == field }
        captionBelow.removeAll { $0 == field }
        if row == .above {
            captionAbove.insert(field, at: min(max(index, 0), captionAbove.count))
        } else {
            captionBelow.insert(field, at: min(max(index, 0), captionBelow.count))
        }
    }

    /// Blur standard deviation in points or pixels for a canvas of `canvasSize`.
    func blurRadius(canvasSize: CGSize) -> Double {
        min(max(blurFraction, Self.blurRange.lowerBound), Self.blurRange.upperBound)
            * min(canvasSize.width, canvasSize.height)
    }
}

nonisolated extension BorderSettings {
    /// Missing keys fall back to the defaults, so settings saved by an older version,
    /// before a field existed, still load instead of being discarded.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BorderSettings()
        aspectRatio = try container.decodeIfPresent(AspectRatio.self, forKey: .aspectRatio) ?? fallback.aspectRatio
        isLandscape = try container.decodeIfPresent(Bool.self, forKey: .isLandscape) ?? fallback.isLandscape
        paddingFraction = try container.decodeIfPresent(Double.self, forKey: .paddingFraction) ?? fallback.paddingFraction
        isPerSide = try container.decodeIfPresent(Bool.self, forKey: .isPerSide) ?? fallback.isPerSide
        sides = try container.decodeIfPresent(BorderInsets.self, forKey: .sides) ?? fallback.sides
        borderColor = try container.decodeIfPresent(Color.Resolved.self, forKey: .borderColor) ?? fallback.borderColor
        fill = try container.decodeIfPresent(BorderFill.self, forKey: .fill) ?? fallback.fill
        blurFraction = try container.decodeIfPresent(Double.self, forKey: .blurFraction) ?? fallback.blurFraction
        showsCaption = try container.decodeIfPresent(Bool.self, forKey: .showsCaption) ?? fallback.showsCaption
        captionFields = try container.decodeIfPresent(Set<CaptionField>.self, forKey: .captionFields) ?? fallback.captionFields
        // Repaired so the rows list every field exactly once: duplicates are dropped, and fields
        // the saved rows don't place (e.g. added in a later version) go at the end of their default row.
        var above = [CaptionField](), below = [CaptionField]()
        for field in try container.decodeIfPresent([CaptionField].self, forKey: .captionAbove) ?? fallback.captionAbove
        where !above.contains(field) {
            above.append(field)
        }
        for field in try container.decodeIfPresent([CaptionField].self, forKey: .captionBelow) ?? fallback.captionBelow
        where !above.contains(field) && !below.contains(field) {
            below.append(field)
        }
        for field in CaptionField.allCases where !above.contains(field) && !below.contains(field) {
            if field.defaultRow == .above { above.append(field) } else { below.append(field) }
        }
        captionAbove = above
        captionBelow = below
        handle = try container.decodeIfPresent(String.self, forKey: .handle) ?? fallback.handle
        handleStyle = try container.decodeIfPresent(HandleStyle.self, forKey: .handleStyle) ?? fallback.handleStyle
        captionHiddenIcons = try container.decodeIfPresent(Set<CaptionField>.self, forKey: .captionHiddenIcons)
            ?? fallback.captionHiddenIcons
        cameraShowsMake = try container.decodeIfPresent(Bool.self, forKey: .cameraShowsMake) ?? fallback.cameraShowsMake
        cameraShowsModel = try container.decodeIfPresent(Bool.self, forKey: .cameraShowsModel) ?? fallback.cameraShowsModel
        captionAlignmentAbove = try container.decodeIfPresent(CaptionAlignment.self, forKey: .captionAlignmentAbove)
            ?? fallback.captionAlignmentAbove
        captionAlignmentBelow = try container.decodeIfPresent(CaptionAlignment.self, forKey: .captionAlignmentBelow)
            ?? fallback.captionAlignmentBelow
        // A font that's since been dropped from the list falls back to the default rather than discarding every setting.
        captionFont = (try? container.decodeIfPresent(CaptionFont.self, forKey: .captionFont)) ?? fallback.captionFont
        showsCaptionIcons = try container.decodeIfPresent(Bool.self, forKey: .showsCaptionIcons) ?? fallback.showsCaptionIcons
        exportWidth = try container.decodeIfPresent(Int.self, forKey: .exportWidth) ?? fallback.exportWidth
    }
}

nonisolated enum ImageComposer {

    struct Layout: Equatable {
        var canvasSize: CGSize
        /// Where the photo sits inside the canvas (top-left origin).
        var imageRect: CGRect
    }

    struct Thumbnail: Sendable {
        let image: UIImage
        /// Upright pixel size of the full-resolution photo.
        let pixelSize: CGSize
        /// Every detail the photo records, for `BorderSettings.showsCaption`.
        let captionItems: [PhotoCaption.Item]
    }

    enum ComposeError: Error {
        case unreadable
        case encodingFailed
    }

    /// Long side of the photo copy the `.blur` fill is blurred at before being scaled up.
    /// A heavy blur has no detail left to lose, so this keeps the blur cheap at any canvas size.
    private static let backdropPixelSize = 512

    /// Bytes the export canvas may use; keeps a 48MP photo with a wide border from exhausting memory.
    /// App extensions get far less memory than the app (Apple doesn't publish the limit), so the
    /// Share-sheet action renders into a smaller canvas: about 10MP at 8 bits per channel.
    static let maxCanvasBytes = Bundle.main.bundleURL.pathExtension == "appex" ? 40_000_000.0 : 400_000_000.0

    /// Canvas pixels that fit in `maxCanvasBytes` for a photo with `bitsPerComponent` bits per channel.
    /// Deeper photos (e.g. 10-bit HEIC) are composited in a 16-bit RGBA canvas (8 bytes per pixel);
    /// everything else uses 8-bit RGBA (4 bytes per pixel).
    static func maxCanvasPixels(bitsPerComponent: Int) -> Double {
        maxCanvasBytes / (bitsPerComponent > 8 ? 8 : 4)
    }

    /// Canvas and photo placement for a photo of `sourceSize` pixels.
    ///
    /// The canvas is as large as needed to draw the photo at its native resolution
    /// (never upscaled), then shrunk to `exportWidth` or `maxPixels` if needed. Everything
    /// scales linearly, so the preview uses the same layout scaled to fit its container.
    /// The default `maxPixels` is the 8-bit budget; `render` passes the budget for the photo's depth.
    static func layout(sourceSize: CGSize, settings: BorderSettings, maxPixels: Double = maxCanvasPixels(bitsPerComponent: 8)) -> Layout {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return Layout(canvasSize: .zero, imageRect: .zero)
        }
        let ratio = settings.canvasWidthOverHeight ?? sourceSize.width / sourceSize.height
        let insets = settings.insets.clamped(to: 0...0.45)
        // Padding is measured on the shorter side; this converts it to units of canvas width.
        let shorterPerWidth = min(1, 1 / ratio)
        let innerWidthPerWidth = 1 - (insets.left + insets.right) * shorterPerWidth
        let innerHeightPerWidth = 1 / ratio - (insets.top + insets.bottom) * shorterPerWidth

        let nativeWidth = max(sourceSize.width / innerWidthPerWidth, sourceSize.height / innerHeightPerWidth)
        var widthLimit = (maxPixels * ratio).squareRoot()
        if settings.exportWidth > 0 {
            widthLimit = min(widthLimit, Double(settings.exportWidth))
        }

        if nativeWidth <= widthLimit {
            // Native resolution: whole-pixel canvas, inset and origin, so the photo is
            // copied pixel for pixel instead of being resampled by a fraction of a pixel.
            // Ignore float noise (e.g. 4032 / (4032 / 3024)) before rounding up.
            func roundUp(_ value: Double) -> Double { max((value - 1e-6).rounded(.up), 1) }
            var width = roundUp(nativeWidth)
            // Rounding the inset can steal a pixel; grow until the photo fits (a few steps at most).
            while width <= widthLimit.rounded() {
                let height = roundUp(width / ratio)
                let shorter = min(width, height)
                let left = (insets.left * shorter).rounded(), right = (insets.right * shorter).rounded()
                let top = (insets.top * shorter).rounded(), bottom = (insets.bottom * shorter).rounded()
                let innerWidth = width - left - right, innerHeight = height - top - bottom
                if innerWidth >= sourceSize.width, innerHeight >= sourceSize.height {
                    // Centered between the borders, so a heavier side pushes the photo away from it.
                    let origin = CGPoint(
                        x: left + ((innerWidth - sourceSize.width) / 2).rounded(.down),
                        y: top + ((innerHeight - sourceSize.height) / 2).rounded(.down)
                    )
                    return Layout(canvasSize: CGSize(width: width, height: height),
                                  imageRect: CGRect(origin: origin, size: sourceSize))
                }
                width += 1
            }
        }

        let width = max(min(nativeWidth, widthLimit).rounded(), 1)
        let height = max((width / ratio).rounded(), 1)
        let shorter = min(width, height)
        let innerWidth = width - (insets.left + insets.right) * shorter
        let innerHeight = height - (insets.top + insets.bottom) * shorter
        let scale = min(innerWidth / sourceSize.width, innerHeight / sourceSize.height, 1)
        let imageSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let imageRect = CGRect(
            x: insets.left * shorter + (innerWidth - imageSize.width) / 2,
            y: insets.top * shorter + (innerHeight - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        return Layout(canvasSize: CGSize(width: width, height: height), imageRect: imageRect)
    }

    /// Downsampled, upright preview of the photo, decoded with ImageIO.
    @concurrent static func thumbnail(from data: Data, filename: String? = nil, maxPixelSize: Int) async throws -> Thumbnail {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let pixelSize = uprightPixelSize(of: source),
              let image = downsample(source, maxPixelSize: maxPixelSize) else {
            throw ComposeError.unreadable
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        return Thumbnail(image: UIImage(cgImage: image), pixelSize: pixelSize, captionItems: PhotoCaption.photoItems(
            from: properties, metadata: CGImageSourceCopyMetadataAtIndex(source, 0, nil), filename: filename))
    }

    /// Draws the photo on its border and encodes it, keeping the source's color space
    /// and metadata minus location. HEIC sources stay HEIC when `keepHEIC` is true;
    /// everything else becomes JPEG.
    ///
    /// HDR photos are exported as their SDR rendition. The border is plain SDR color, and
    /// re-encoding with a gain map tone-maps the whole canvas, which shifts both the photo's
    /// exposure and the border color.
    ///
    /// Renders run one at a time, whoever calls (a Download, or the share sheet loading
    /// several photos at once), so only one canvas of up to `maxCanvasBytes` exists at a time.
    static func render(_ data: Data, filename: String? = nil, settings: BorderSettings, keepHEIC: Bool = true) async throws -> Data {
        try await renderQueue.run {
            try await renderNow(data, filename: filename, settings: settings, keepHEIC: keepHEIC)
        }
    }

    private static let renderQueue = SerialQueue()

    @concurrent private static func renderNow(_ data: Data, filename: String?, settings: BorderSettings, keepHEIC: Bool) async throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let pixelSize = uprightPixelSize(of: source) else {
            throw ComposeError.unreadable
        }
        // Budget the canvas for the depth it will be composited at, so 16-bit canvases stay within maxCanvasBytes.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let deep = (properties?[kCGImagePropertyDepth] as? Int ?? 8) > 8
        let layout = layout(sourceSize: pixelSize, settings: settings,
                            maxPixels: maxCanvasPixels(bitsPerComponent: deep ? 16 : 8))
        let longestSide = Int(max(layout.imageRect.width, layout.imageRect.height).rounded(.up))
        // Scoped so the decoded photo is freed before encoding.
        let canvas = try {
            guard let image = downsample(source, maxPixelSize: longestSide) else {
                throw ComposeError.unreadable
            }
            let backdrop = settings.fill == .blur
                ? try blurredBackdrop(source, canvasSize: layout.canvasSize,
                                      radius: settings.blurRadius(canvasSize: layout.canvasSize))
                : nil
            let caption = PhotoCaption.rows(photoItems: PhotoCaption.photoItems(
                from: properties ?? [:], metadata: CGImageSourceCopyMetadataAtIndex(source, 0, nil), filename: filename),
                                            settings: settings)
            return try composite(image, layout: layout, settings: settings, caption: caption,
                                 backdrop: backdrop, allowDeep: deep)
        }()

        let metadata = exportMetadata(source)
        let sourceType = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
        let isHEIC = sourceType?.conforms(to: .heic) == true || sourceType?.conforms(to: .heif) == true
        for type in isHEIC && keepHEIC ? [UTType.heic, .jpeg] : [.jpeg] {
            if let encoded = encode(canvas, as: type, metadata: metadata) {
                return encoded
            }
        }
        throw ComposeError.encodingFailed
    }

    // MARK: - ImageIO helpers

    private static func uprightPixelSize(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else {
            return nil
        }
        // EXIF orientations 5–8 are rotated a quarter turn.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    /// Decodes the SDR rendition (an HDR photo's gain map is ignored).
    private static func downsample(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// A small, blurred copy of the photo for the `.blur` fill, blurred so that once it's scaled to
    /// cover a canvas of `canvasSize` its blur has a standard deviation of `radius` canvas pixels.
    private static func blurredBackdrop(_ source: CGImageSource, canvasSize canvas: CGSize, radius: Double) throws -> CGImage {
        guard let small = downsample(source, maxPixelSize: backdropPixelSize) else {
            throw ComposeError.unreadable
        }
        let scaleUp = max(canvas.width / Double(small.width), canvas.height / Double(small.height))
        let sigma = radius / scaleUp
        let input = CIImage(cgImage: small)
        // Clamping first keeps the edges from blurring into transparency.
        let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: input.extent)
        let space = small.colorSpace.flatMap { $0.model == .rgb && $0.supportsOutput ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let result = CIContext(options: [.cacheIntermediates: false])
                .createCGImage(blurred, from: input.extent, format: .RGBA8, colorSpace: space) else {
            throw ComposeError.encodingFailed
        }
        return result
    }

    /// Draws `image` on a canvas filled with `backdrop` scaled to cover it, or with the border color
    /// when there's no backdrop, then `caption` in rows above and below the photo. A 16-bit canvas is used only when the decoded image is deeper
    /// than 8 bits and `allowDeep` says the layout was budgeted for 8 bytes per pixel.
    private static func composite(_ image: CGImage, layout: Layout, settings: BorderSettings, caption: PhotoCaption.Rows,
                                  backdrop: CGImage?, allowDeep: Bool) throws -> CGImage {
        let width = Int(layout.canvasSize.width)
        let height = Int(layout.canvasSize.height)
        // Draw in the photo's own RGB color space (e.g. Display P3) so wide color survives.
        let sourceSpace = image.colorSpace.flatMap { $0.model == .rgb && $0.supportsOutput ? $0 : nil }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let context: CGContext?
        if allowDeep && image.bitsPerComponent > 8 {
            context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 16, bytesPerRow: 0,
                                space: sourceSpace ?? sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        } else {
            context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: sourceSpace ?? sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        }
        guard let context = context
                ?? CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                             space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw ComposeError.encodingFailed
        }
        context.interpolationQuality = .high
        if let backdrop {
            let canvas = layout.canvasSize
            let scale = max(canvas.width / Double(backdrop.width), canvas.height / Double(backdrop.height))
            let size = CGSize(width: Double(backdrop.width) * scale, height: Double(backdrop.height) * scale)
            // Centered, so the bottom-left origin doesn't matter.
            context.draw(backdrop, in: CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                                              width: size.width, height: size.height))
        } else {
            context.setFillColor(settings.borderColor.cgColor)
            context.fill(CGRect(origin: .zero, size: layout.canvasSize))
        }
        // Core Graphics has a bottom-left origin.
        var drawRect = layout.imageRect
        drawRect.origin.y = layout.canvasSize.height - layout.imageRect.maxY
        context.draw(image, in: drawRect)
        PhotoCaption.draw(caption, in: context, layout: layout, border: settings.borderColor, fill: settings.fill)
        guard let result = context.makeImage() else {
            throw ComposeError.encodingFailed
        }
        return result
    }

    /// Source metadata minus what no longer applies (pixels are already upright and resized)
    /// and minus location and maker notes, which a photo posted online shouldn't carry.
    /// Location means GPS plus the IPTC place fields (city, state, country, sublocation and
    /// the IPTC Extension location structures); other IPTC fields such as creator and copyright are kept.
    private static func exportMetadata(_ source: CGImageSource) -> [CFString: Any] {
        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        for key in [kCGImagePropertyOrientation, kCGImagePropertyPixelWidth, kCGImagePropertyPixelHeight,
                    kCGImagePropertyGPSDictionary, kCGImagePropertyMakerAppleDictionary] {
            metadata.removeValue(forKey: key)
        }
        if var tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation)
            metadata[kCGImagePropertyTIFFDictionary] = tiff
        }
        if var iptc = metadata[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
            for key in [kCGImagePropertyIPTCCity, kCGImagePropertyIPTCSubLocation, kCGImagePropertyIPTCProvinceState,
                        kCGImagePropertyIPTCCountryPrimaryLocationName, kCGImagePropertyIPTCCountryPrimaryLocationCode,
                        kCGImagePropertyIPTCContentLocationName, kCGImagePropertyIPTCContentLocationCode,
                        kCGImagePropertyIPTCExtLocationCreated, kCGImagePropertyIPTCExtLocationShown] {
                iptc.removeValue(forKey: key)
            }
            if iptc.isEmpty {
                metadata.removeValue(forKey: kCGImagePropertyIPTCDictionary)
            } else {
                metadata[kCGImagePropertyIPTCDictionary] = iptc
            }
        }
        if var exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif.removeValue(forKey: kCGImagePropertyExifPixelXDimension)
            exif.removeValue(forKey: kCGImagePropertyExifPixelYDimension)
            metadata[kCGImagePropertyExifDictionary] = exif
        }
        metadata[kCGImageDestinationLossyCompressionQuality] = 0.95
        return metadata
    }

    private static func encode(_ image: CGImage, as type: UTType, metadata: [CFString: Any]) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

/// Runs async work one job at a time, in the order it was submitted.
private actor SerialQueue {
    private var last: Task<Void, Never>?

    func run<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        // Chained before the first suspension, so submission order is preserved.
        let previous = last
        let job = Task<T, any Error> {
            await previous?.value
            return try await work()
        }
        last = Task { _ = try? await job.value }
        return try await job.value
    }
}
