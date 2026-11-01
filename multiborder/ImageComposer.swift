//
//  ImageComposer.swift
//  multiborder
//
//  Geometry shared by the on-screen preview and the export, plus the
//  ImageIO work (thumbnails, compositing, encoding) that runs off the main actor.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

nonisolated enum AspectRatio: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case twoByThree = "2:3"
    case threeByFour = "3:4"
    case fourByFive = "4:5"
    case square = "1:1"

    var id: Self { self }

    var title: String { self == .original ? "Original" : rawValue }

    /// Width divided by height; `nil` keeps the photo's own ratio.
    var widthOverHeight: Double? {
        switch self {
        case .original: nil
        case .twoByThree: 2.0 / 3.0
        case .threeByFour: 3.0 / 4.0
        case .fourByFive: 4.0 / 5.0
        case .square: 1.0
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

nonisolated struct BorderSettings: Codable, Equatable, Sendable {
    static let paddingRange: ClosedRange<Double> = 0...0.16

    var aspectRatio: AspectRatio = .fourByFive
    /// Border thickness as a fraction of the canvas's shorter side.
    var paddingFraction: Double = 0
    var borderColor: Color.Resolved = Color.Resolved(red: 1, green: 1, blue: 1)
    /// Maximum output width in pixels; 0 exports at the photo's full resolution.
    var exportWidth: Int = 0
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
    }

    enum ComposeError: Error {
        case unreadable
        case encodingFailed
    }

    /// Bytes the export canvas may use; keeps a 48MP photo with a wide border from exhausting memory.
    static let maxCanvasBytes = 400_000_000.0

    /// Canvas and photo placement for a photo of `sourceSize` pixels.
    ///
    /// The canvas is as large as needed to draw the photo at its native resolution
    /// (never upscaled), then shrunk to `exportWidth` or `maxPixels` if needed. Everything
    /// scales linearly, so the preview uses the same layout scaled to fit its container.
    static func layout(sourceSize: CGSize, settings: BorderSettings, maxPixels: Double = maxCanvasBytes / 4) -> Layout {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return Layout(canvasSize: .zero, imageRect: .zero)
        }
        let ratio = settings.aspectRatio.widthOverHeight ?? sourceSize.width / sourceSize.height
        let padding = min(max(settings.paddingFraction, 0), 0.45)
        // Padding per unit of canvas width (it is measured on the shorter side).
        let paddingPerWidth = padding * min(1, 1 / ratio)
        let innerWidthPerWidth = 1 - 2 * paddingPerWidth
        let innerHeightPerWidth = 1 / ratio - 2 * paddingPerWidth

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
                let inset = (padding * min(width, height)).rounded()
                if width - 2 * inset >= sourceSize.width, height - 2 * inset >= sourceSize.height {
                    let origin = CGPoint(
                        x: ((width - sourceSize.width) / 2).rounded(.down),
                        y: ((height - sourceSize.height) / 2).rounded(.down)
                    )
                    return Layout(canvasSize: CGSize(width: width, height: height),
                                  imageRect: CGRect(origin: origin, size: sourceSize))
                }
                width += 1
            }
        }

        let width = max(min(nativeWidth, widthLimit).rounded(), 1)
        let height = max((width / ratio).rounded(), 1)
        let inset = padding * min(width, height)
        let scale = min((width - 2 * inset) / sourceSize.width, (height - 2 * inset) / sourceSize.height, 1)
        let imageSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let imageRect = CGRect(
            x: (width - imageSize.width) / 2,
            y: (height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        return Layout(canvasSize: CGSize(width: width, height: height), imageRect: imageRect)
    }

    /// Downsampled, upright preview of the photo, decoded with ImageIO.
    @concurrent static func thumbnail(from data: Data, maxPixelSize: Int) async throws -> Thumbnail {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let pixelSize = uprightPixelSize(of: source),
              let image = downsample(source, maxPixelSize: maxPixelSize) else {
            throw ComposeError.unreadable
        }
        return Thumbnail(image: UIImage(cgImage: image), pixelSize: pixelSize)
    }

    /// Draws the photo on its border and encodes it, keeping the source's color space
    /// and metadata minus location. HEIC sources stay HEIC; everything else becomes JPEG.
    ///
    /// HDR photos are exported as their SDR rendition. The border is plain SDR color, and
    /// re-encoding with a gain map tone-maps the whole canvas, which shifts both the photo's
    /// exposure and the border color.
    @concurrent static func render(_ data: Data, settings: BorderSettings) async throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let pixelSize = uprightPixelSize(of: source) else {
            throw ComposeError.unreadable
        }
        let layout = layout(sourceSize: pixelSize, settings: settings)
        let longestSide = Int(max(layout.imageRect.width, layout.imageRect.height).rounded(.up))
        // Scoped so the decoded photo is freed before encoding.
        let canvas = try {
            guard let image = downsample(source, maxPixelSize: longestSide) else {
                throw ComposeError.unreadable
            }
            return try composite(image, layout: layout, borderColor: settings.borderColor.cgColor)
        }()

        let metadata = exportMetadata(source)
        let sourceType = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
        let isHEIC = sourceType?.conforms(to: .heic) == true || sourceType?.conforms(to: .heif) == true
        for type in isHEIC ? [UTType.heic, .jpeg] : [.jpeg] {
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

    private static func composite(_ image: CGImage, layout: Layout, borderColor: CGColor) throws -> CGImage {
        let width = Int(layout.canvasSize.width)
        let height = Int(layout.canvasSize.height)
        // Draw in the photo's own RGB color space (e.g. Display P3) so wide color survives.
        let sourceSpace = image.colorSpace.flatMap { $0.model == .rgb && $0.supportsOutput ? $0 : nil }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let context: CGContext?
        if image.bitsPerComponent > 8 {
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
        context.setFillColor(borderColor)
        context.fill(CGRect(origin: .zero, size: layout.canvasSize))
        // Core Graphics has a bottom-left origin.
        var drawRect = layout.imageRect
        drawRect.origin.y = layout.canvasSize.height - layout.imageRect.maxY
        context.draw(image, in: drawRect)
        guard let result = context.makeImage() else {
            throw ComposeError.encodingFailed
        }
        return result
    }

    /// Source metadata minus what no longer applies (pixels are already upright and resized)
    /// and minus location and maker notes, which a photo posted online shouldn't carry.
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
