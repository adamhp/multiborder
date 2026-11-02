//
//  PhotoCaption.swift
//  multiborder
//
//  The details printed in a row just above and a row just below the photo, shared by the preview and the export.
//

import SwiftUI
import CoreText
import ImageIO

/// Which side of the photo a caption row is printed on.
nonisolated enum CaptionRow: String, Codable, Sendable {
    case above
    case below
}

/// How a caption row's items are arranged across the photo's width.
nonisolated enum CaptionAlignment: String, CaseIterable, Codable, Sendable {
    /// The first item at the photo's left edge, the last at its right, with equal space between.
    case spread
    case leading
    case center
    case trailing

    var symbolName: String {
        switch self {
        case .spread: "text.justify"
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }

    var title: String {
        switch self {
        case .spread: "Spread"
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        }
    }

    /// The next arrangement, for a button that cycles through them.
    var next: CaptionAlignment {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// One piece of the caption, each with its own toggle, placed in either row by `BorderSettings`.
nonisolated enum CaptionField: String, CaseIterable, Codable, Sendable {
    case date
    case title
    case filename
    case handle
    case camera
    case focalLength
    case aperture
    case shutter
    case iso

    /// The row a field starts in, and goes back to if a saved layout doesn't place it.
    var defaultRow: CaptionRow {
        switch self {
        case .date, .title, .filename, .handle: .above
        default: .below
        }
    }

    /// The icon printed before the value. ISO, the title and the filename have none: their text speaks for
    /// itself. The handle's depends on `BorderSettings.handleStyle`.
    var icon: CaptionIcon? {
        switch self {
        case .date: .symbol("calendar")
        case .title, .filename: nil
        case .handle: nil
        case .camera: .symbol("camera")
        case .focalLength: .symbol("scope")
        case .aperture: .symbol("camera.aperture")
        case .shutter: .symbol("timer")
        case .iso: nil
        }
    }

    var title: String {
        switch self {
        case .date: "Date"
        case .title: "Title"
        case .filename: "Filename"
        case .handle: "Handle"
        case .camera: "Camera"
        case .focalLength: "Focal Length"
        case .aperture: "Aperture"
        case .shutter: "Shutter Speed"
        case .iso: "ISO"
        }
    }
}

/// Where the handle points, shown as the icon before it.
nonisolated enum HandleStyle: String, CaseIterable, Codable, Sendable {
    case instagram
    case flickr
    case at
    case website
    /// Just the name, with no icon.
    case plain

    var title: String {
        switch self {
        case .instagram: "Instagram"
        case .flickr: "Flickr"
        case .at: "@"
        case .website: "Website"
        case .plain: "Text Only"
        }
    }

    /// `nil` for `.at`, which prints the handle as "@name" instead, and for `.plain`.
    var icon: CaptionIcon? {
        switch self {
        case .instagram: .glyph(.instagram)
        case .flickr: .glyph(.flickr)
        case .at, .plain: nil
        case .website: .symbol("globe")
        }
    }

    /// What stands for this style in the controls: its icon, or a symbol for the styles printed without one.
    var controlIcon: CaptionIcon? {
        self == .plain ? .symbol("textformat") : icon
    }
}

nonisolated enum CaptionIcon: Equatable, Sendable {
    /// An SF Symbol.
    case symbol(String)
    /// A mark with no SF Symbol, drawn from a path.
    case glyph(CaptionGlyph)

    /// Space kept under the icon, as a share of its box's height. The camera symbol's drawing sits low in
    /// its image, so it's lifted (and shrunk a little) to line up with the text.
    var bottomPadding: Double {
        self == .symbol("camera") ? 0.12 : 0
    }
}

/// Simple monochrome marks for sites that SF Symbols doesn't cover.
nonisolated enum CaptionGlyph: Sendable {
    case instagram
    case flickr

    /// The mark in a unit square (top-left origin), to be filled with the even-odd rule.
    var unitPath: CGPath {
        let path = CGMutablePath()
        switch self {
        case .instagram:
            // A rounded square outline, a ring inside it, and a dot at the top right.
            path.addRoundedRect(in: CGRect(x: 0, y: 0, width: 1, height: 1), cornerWidth: 0.28, cornerHeight: 0.28)
            path.addRoundedRect(in: CGRect(x: 0.09, y: 0.09, width: 0.82, height: 0.82), cornerWidth: 0.2, cornerHeight: 0.2)
            path.addEllipse(in: CGRect(x: 0.27, y: 0.27, width: 0.46, height: 0.46))
            path.addEllipse(in: CGRect(x: 0.36, y: 0.36, width: 0.28, height: 0.28))
            path.addEllipse(in: CGRect(x: 0.70, y: 0.18, width: 0.12, height: 0.12))
        case .flickr:
            // Two dots side by side.
            path.addEllipse(in: CGRect(x: 0.04, y: 0.29, width: 0.42, height: 0.42))
            path.addEllipse(in: CGRect(x: 0.54, y: 0.29, width: 0.42, height: 0.42))
        }
        return path
    }
}

nonisolated enum PhotoCaption {

    struct Item: Equatable, Sendable {
        let field: CaptionField
        let text: String
        var icon: CaptionIcon?
        /// For a photo's `.camera` item: the maker, kept apart from the model in `text`
        /// so `rows` can print either or both as the settings ask.
        var make: String?

        init(field: CaptionField, text: String, icon: CaptionIcon? = nil, make: String? = nil) {
            self.field = field
            self.text = text
            self.icon = icon ?? field.icon
            self.make = make
        }
    }

    /// What's printed above and below the photo, left to right.
    struct Rows: Equatable, Sendable {
        var above: [Item] = []
        var below: [Item] = []
        var aboveAlignment = CaptionAlignment.spread
        var belowAlignment = CaptionAlignment.spread
    }

    /// Where each item goes, in canvas units (top-left origin). Both rows share one text size.
    struct Placement: Equatable {
        struct Entry: Equatable {
            var item: Item
            /// The item's icon and value together.
            var frame: CGRect
        }

        var fontSize: Double
        /// The box each icon is fitted into: as tall as the text's capital letters.
        var iconSize: CGSize
        /// Space between an icon and its value.
        var iconGap: Double
        var entries: [Entry]
        /// The font's line box above and below the baseline at `fontSize`.
        var ascent: Double
        var descent: Double

        /// Where an item's value starts, after its icon if it has one.
        func textOffset(for item: Item) -> Double {
            item.icon == nil ? 0 : iconSize.width + iconGap
        }

        /// The baseline of a line of text centered in `frame` (top-left origin).
        func baseline(in frame: CGRect) -> Double {
            frame.midY + (ascent - descent) / 2
        }

        /// Where an entry's icon goes (top-left origin): standing on the text's baseline, as tall as its capitals.
        func iconRect(for entry: Entry) -> CGRect {
            let padding = iconSize.height * (entry.item.icon?.bottomPadding ?? 0)
            return CGRect(x: entry.frame.minX, y: baseline(in: entry.frame) - iconSize.height,
                          width: iconSize.width, height: iconSize.height - padding)
        }
    }

    static let fontName = "SpaceMono-Regular"
    /// Font size as a share of the canvas's shorter side, before it's limited by the room available.
    private static let sizeShare = 0.022
    /// A border must be this many font sizes deep: the space beside the photo, the row, and some beyond.
    private static let gapInFontSizes = 2.6
    /// Space between the photo and the row, in font sizes.
    private static let photoSpacing = 0.8
    /// Least space between two spread items, in font sizes.
    private static let minimumSpacing = 1.0
    /// Space between items that aren't spread, in font sizes.
    private static let groupedSpacing = 1.5
    /// An icon's box is this many times as wide as it is tall, so wide symbols keep their full height.
    private static let iconAspect = 1.3
    /// Space after an icon, in font sizes.
    private static let iconGapShare = 0.35

    // MARK: - Content

    /// Longest title printed; a longer caption is cut short so it can't shrink the whole row.
    private static let maxTitleLength = 60
    /// Descriptions some cameras write on every photo, which say nothing about it.
    private static let cameraDefaultDescriptions: Set<String> = [
        "olympus digital camera", "sony dsc", "digital camera", "default", "image", "picture",
    ]

    /// Every detail that comes from the photo: what `properties` (its ImageIO properties) and `metadata`
    /// (its XMP) record, and its `filename`.
    static func photoItems(from properties: [CFString: Any], metadata: CGImageMetadata? = nil, filename: String? = nil) -> [Item] {
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
        return CaptionField.allCases.compactMap { field in
            if field == .camera {
                // Kept as separate parts; `cameraItem` puts together what the settings ask for.
                let make = (tiff[kCGImagePropertyTIFFMake] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                let model = (tiff[kCGImagePropertyTIFFModel] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !make.isEmpty || !model.isEmpty else { return nil }
                return Item(field: .camera, text: model, make: make.isEmpty ? nil : make)
            }
            let text = switch field {
            case .title: title(tiff: tiff, iptc: iptc, metadata: metadata)
            case .filename: filename.flatMap(cleanFilename)
            default: text(of: field, tiff: tiff, exif: exif)
            }
            return text.map { Item(field: field, text: $0) }
        }
    }

    /// The photo's title, or failing that its caption or description, from IPTC, XMP or TIFF.
    /// Text that only names the camera, or that cameras write by default, is skipped.
    private static func title(tiff: [CFString: Any], iptc: [CFString: Any], metadata: CGImageMetadata?) -> String? {
        let make = (tiff[kCGImagePropertyTIFFMake] as? String ?? "").lowercased()
        let model = (tiff[kCGImagePropertyTIFFModel] as? String ?? "").lowercased()
        /// An XMP text value. Titles and descriptions are usually stored per language, so the first one is the fallback.
        func xmp(_ path: String) -> String? {
            guard let metadata else { return nil }
            return [path, path + "[1]"].lazy
                .compactMap { CGImageMetadataCopyStringValueWithPath(metadata, nil, $0 as CFString) as String? }
                .first
        }
        let candidates: [String?] = [
            iptc[kCGImagePropertyIPTCObjectName] as? String,
            xmp("dc:title"),
            iptc[kCGImagePropertyIPTCCaptionAbstract] as? String,
            xmp("dc:description"),
            tiff[kCGImagePropertyTIFFImageDescription] as? String,
        ]
        for candidate in candidates {
            // One line, with runs of spaces and line breaks collapsed.
            let text = (candidate ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let lowered = text.lowercased()
            guard !text.isEmpty, !cameraDefaultDescriptions.contains(lowered),
                  make.isEmpty || !lowered.contains(make), model.isEmpty || !lowered.contains(model) else { continue }
            return text.count > maxTitleLength ? text.prefix(maxTitleLength - 1).trimmingCharacters(in: .whitespaces) + "…" : text
        }
        return nil
    }

    /// The filename without its extension, e.g. "IMG_1234" for "IMG_1234.HEIC".
    private static func cleanFilename(_ filename: String) -> String? {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (trimmed as NSString).deletingPathExtension
        let result = name.isEmpty ? trimmed : name
        return result.isEmpty ? nil : result
    }

    /// What `settings` prints for a photo with `photoItems`; empty while the caption is off.
    static func rows(photoItems: [Item], settings: BorderSettings) -> Rows {
        guard settings.showsCaption else { return Rows() }
        func items(_ row: CaptionRow) -> [Item] {
            settings.includedCaptionFields(in: row).compactMap { field in
                var item = switch field {
                case .handle: handleItem(settings)
                case .camera: photoItems.first { $0.field == .camera }.flatMap { cameraItem($0, settings: settings) }
                default: photoItems.first { $0.field == field }
                }
                // The handle's icon comes from its style, which has its own text-only choice.
                if field != .handle && settings.captionHiddenIcons.contains(field) {
                    item?.icon = nil
                }
                return item
            }
        }
        return Rows(above: items(.above), below: items(.below),
                    aboveAlignment: settings.captionAlignmentAbove, belowAlignment: settings.captionAlignmentBelow)
    }

    /// A photo's camera as the settings ask: its make, its model, or both. The make isn't repeated
    /// when the model already names it (e.g. "Canon EOS R5"). `nil` when nothing chosen is recorded.
    static func cameraItem(_ photoItem: Item, settings: BorderSettings) -> Item? {
        let model = settings.cameraShowsModel ? photoItem.text : ""
        var make = settings.cameraShowsMake ? photoItem.make ?? "" : ""
        if !model.isEmpty && model.localizedCaseInsensitiveContains(make) {
            make = ""
        }
        let text = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return text.isEmpty ? nil : Item(field: .camera, text: text)
    }

    /// The handle as typed, without any leading "@"; `nil` when there's none.
    static func handleItem(_ settings: BorderSettings) -> Item? {
        let name = settings.handle.trimmingCharacters(in: .whitespaces)
            .drop { $0 == "@" }.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let style = settings.handleStyle
        return Item(field: .handle, text: style == .at ? "@" + name : name, icon: style.icon)
    }

    private static func text(of field: CaptionField, tiff: [CFString: Any], exif: [CFString: Any]) -> String? {
        switch field {
        case .date:
            let stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String ?? tiff[kCGImagePropertyTIFFDateTime] as? String
            return stamp.flatMap(formattedDate)
        case .title, .filename, .handle:
            return nil
        case .camera:
            return nil
        case .focalLength:
            // The 35mm equivalent is what people compare; the actual focal length is the fallback.
            guard let focal = (exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double)
                    ?? (exif[kCGImagePropertyExifFocalLength] as? Double), focal > 0 else { return nil }
            return "\(Int(focal.rounded()))mm"
        case .aperture:
            guard let aperture = exif[kCGImagePropertyExifFNumber] as? Double, aperture > 0 else { return nil }
            return "ƒ/" + decimal(aperture)
        case .shutter:
            guard let exposure = exif[kCGImagePropertyExifExposureTime] as? Double, exposure > 0 else { return nil }
            return exposure < 1 ? "1/\(Int((1 / exposure).rounded()))s" : decimal(exposure) + "s"
        case .iso:
            // ImageIO stores ISO as an array of numbers.
            guard let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber])?.first?.intValue, iso > 0 else { return nil }
            return "ISO \(iso)"
        }
    }

    /// An EXIF date ("2026:11:02 14:05:09") as a short date in the user's locale, e.g. "Nov 2, 2026".
    /// EXIF dates carry no time zone; reading and writing both in GMT keeps the day as the camera recorded it.
    private static func formattedDate(_ stamp: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .gmt
        parser.dateFormat = "yyyy:MM:dd HH:mm:ss"
        guard let date = parser.date(from: stamp) else { return nil }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
    }

    /// One decimal place, without a trailing ".0".
    private static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    // MARK: - Layout

    /// Lays each row out just beside the photo, arranged by its `CaptionAlignment`: spread so its first item
    /// starts at the photo's left edge and its last ends at the right edge (a single item is centered), or
    /// grouped at the left, center or right. The text shrinks to fit the borders' depth and the photo's width.
    /// A row with no border to print in is left out; `nil` when nothing is placed.
    static func placement(of rows: Rows, layout: ImageComposer.Layout) -> Placement? {
        let canvas = layout.canvasSize
        let photo = layout.imageRect
        guard photo.width > 0 else { return nil }
        let printed: [(row: CaptionRow, items: [Item], gap: Double, alignment: CaptionAlignment)] = [
            (CaptionRow.above, rows.above, Double(photo.minY), rows.aboveAlignment),
            (CaptionRow.below, rows.below, Double(canvas.height - photo.maxY), rows.belowAlignment),
        ].filter { !$0.items.isEmpty && $0.gap >= 1 }
        guard !printed.isEmpty else { return nil }

        // Every width grows in proportion to the font size, so measure at size 1 and scale.
        func widthsAtOne(_ items: [Item]) -> [Double] {
            items.map { ($0.icon == nil ? 0 : capHeight(fontSize: 1) * iconAspect + iconGapShare) + textWidth($0.text, fontSize: 1) }
        }
        var fontSize = min(canvas.width, canvas.height) * sizeShare
        for (_, items, gap, alignment) in printed {
            let spacing = alignment == .spread ? minimumSpacing : groupedSpacing
            let neededAtOne = widthsAtOne(items).reduce(0, +) + spacing * Double(items.count - 1)
            fontSize = min(fontSize, gap / gapInFontSizes, photo.width / neededAtOne)
        }

        let rowHeight = fontSize * 1.2
        var entries = [Placement.Entry]()
        for (row, items, _, alignment) in printed {
            let widths = widthsAtOne(items).map { $0 * fontSize }
            let y = row == .above
                ? photo.minY - fontSize * photoSpacing - rowHeight
                : photo.maxY + fontSize * photoSpacing
            let spacing: Double
            var x: Double
            if alignment == .spread {
                spacing = items.count > 1 ? (photo.width - widths.reduce(0, +)) / Double(items.count - 1) : 0
                x = items.count > 1 ? photo.minX : photo.midX - widths[0] / 2
            } else {
                spacing = fontSize * groupedSpacing
                let total = widths.reduce(0, +) + spacing * Double(items.count - 1)
                x = switch alignment {
                case .leading: photo.minX
                case .trailing: photo.maxX - total
                default: photo.midX - total / 2
                }
            }
            for (item, width) in zip(items, widths) {
                entries.append(Placement.Entry(item: item, frame: CGRect(x: x, y: y, width: width, height: rowHeight)))
                x += width + spacing
            }
        }
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let cap = CTFontGetCapHeight(font)
        return Placement(fontSize: fontSize, iconSize: CGSize(width: cap * iconAspect, height: cap),
                         iconGap: fontSize * iconGapShare, entries: entries,
                         ascent: CTFontGetAscent(font), descent: CTFontGetDescent(font))
    }

    /// Dark text on a light border, light text on a dark one.
    static func color(on border: Color.Resolved, fill: BorderFill) -> Color.Resolved {
        // Over the blurred photo there's no single border color, so light text with a shadow.
        guard fill == .color else { return Color.Resolved(red: 1, green: 1, blue: 1, opacity: 0.9) }
        // Color.Resolved components are linear, which is what relative luminance wants.
        let luminance = 0.2126 * border.red + 0.7152 * border.green + 0.0722 * border.blue
        return luminance > 0.25
            ? Color.Resolved(red: 0, green: 0, blue: 0, opacity: 0.7)
            : Color.Resolved(red: 1, green: 1, blue: 1, opacity: 0.8)
    }

    // MARK: - Export drawing

    /// Draws `rows` into a Core Graphics `context` whose canvas is `layout.canvasSize` (bottom-left origin).
    static func draw(_ rows: Rows, in context: CGContext, layout: ImageComposer.Layout,
                     border: Color.Resolved, fill: BorderFill) {
        guard let placement = placement(of: rows, layout: layout) else { return }
        let color = color(on: border, fill: fill).cgColor
        let height = layout.canvasSize.height
        context.saveGState()
        if fill == .blur {
            context.setShadow(offset: .zero, blur: placement.fontSize * 0.4, color: CGColor(gray: 0, alpha: 0.5))
        }
        for entry in placement.entries {
            let box = placement.iconRect(for: entry)
            // The icon's box, flipped to the bottom-left origin.
            let iconRect = CGRect(x: box.minX, y: height - box.maxY, width: box.width, height: box.height)
            switch entry.item.icon {
            case .symbol(let name):
                if let symbol = symbolImage(name, color: color, size: iconRect.size) {
                    context.draw(symbol, in: iconRect)
                }
            case .glyph(let glyph):
                context.saveGState()
                // The glyph's unit square, centered in the box at its full height; flipped while
                // scaling it up, since it has a top-left origin.
                let side = iconRect.height
                context.translateBy(x: iconRect.midX - side / 2, y: iconRect.maxY)
                context.scaleBy(x: side, y: -side)
                context.addPath(glyph.unitPath)
                context.setFillColor(color)
                context.fillPath(using: .evenOdd)
                context.restoreGState()
            case nil:
                break
            }
            // The line box is centered in the frame, as SwiftUI centers the preview's `Text`.
            let line = line(entry.item.text, fontSize: placement.fontSize, color: color)
            context.textPosition = CGPoint(x: entry.frame.minX + placement.textOffset(for: entry.item),
                                           y: height - placement.baseline(in: entry.frame))
            CTLineDraw(line, context)
        }
        context.restoreGState()
    }

    /// The symbol in `color`, fitted and centered in a box of `size` pixels.
    private static func symbolImage(_ name: String, color: CGColor, size box: CGSize) -> CGImage? {
        let width = max(box.width.rounded(.up), 1), height = max(box.height.rounded(.up), 1)
        guard let symbol = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: height))?
                .withTintColor(UIColor(cgColor: color), renderingMode: .alwaysOriginal),
              symbol.size.width > 0, symbol.size.height > 0 else { return nil }
        let fit = min(width / symbol.size.width, height / symbol.size.height)
        let size = CGSize(width: symbol.size.width * fit, height: symbol.size.height * fit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
            symbol.draw(in: CGRect(x: (width - size.width) / 2, y: (height - size.height) / 2,
                                   width: size.width, height: size.height))
        }.cgImage
    }

    /// Height of the font's capital letters at `fontSize`.
    private static func capHeight(fontSize: Double) -> Double {
        CTFontGetCapHeight(CTFontCreateWithName(fontName as CFString, fontSize, nil))
    }

    private static func textWidth(_ text: String, fontSize: Double) -> Double {
        CTLineGetTypographicBounds(line(text, fontSize: fontSize, color: CGColor(gray: 0, alpha: 1)), nil, nil, nil)
    }

    private static func line(_ text: String, fontSize: Double, color: CGColor) -> CTLine {
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        return CTLineCreateWithAttributedString(attributed)
    }
}

/// A caption icon in the current foreground style, fitted to the frame it's given.
struct CaptionIconView: View {

    let icon: CaptionIcon

    var body: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
        case .glyph(let glyph):
            GlyphShape(glyph: glyph)
                .fill(style: FillStyle(eoFill: true))
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

private struct GlyphShape: Shape {

    let glyph: CaptionGlyph

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let transform = CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
            .scaledBy(x: side, y: side)
        return Path(glyph.unitPath).applying(transform)
    }
}
