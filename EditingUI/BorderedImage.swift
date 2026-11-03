//
//  BorderedImage.swift
//  multiborder
//
//  The bordered photo as the Edit page previews it, shared by the app and the Photo Editing Extension.
//

import SwiftUI

/// The photo with its border, centered in the space it's given, with an HDR badge for HDR photos.
struct BorderedPreview: View {

    let thumbnail: ImageComposer.Thumbnail
    let settings: BorderSettings

    var body: some View {
        GeometryReader { geo in
            BorderedImage(thumbnail: thumbnail, settings: settings, containerSize: geo.size)
                .overlay(alignment: .topTrailing) {
                    if thumbnail.hdrImage != nil {
                        HDRBadge(saved: settings.savesHDR, settings: settings)
                            .padding(6)
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// Marks an HDR photo: bright when Download keeps its highlights, dimmed when Keep HDR or PNG rules them out.
struct HDRBadge: View {

    let saved: Bool
    let settings: BorderSettings

    var body: some View {
        Text(saved ? "HDR" : "HDR off")
            .font(.spaceMono(11).bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: .capsule)
            .opacity(saved ? 1 : 0.6)
            .animation(.default, value: saved)
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if saved { String(localized: "HDR photo, saved with its highlights") }
        else if !settings.keepsHDR { String(localized: "HDR photo, saved at standard brightness because Keep HDR is off") }
        else { String(localized: "HDR photo, saved at standard brightness because PNG can’t hold HDR") }
    }
}

/// The export layout scaled down to fit `containerSize`, so the preview matches the export.
struct BorderedImage: View {

    let thumbnail: ImageComposer.Thumbnail
    let settings: BorderSettings
    let containerSize: CGSize

    var body: some View {
        let layout = ImageComposer.layout(sourceSize: thumbnail.pixelSize, settings: settings)
        let scale = layout.canvasSize.width > 0
            ? min(containerSize.width / layout.canvasSize.width, containerSize.height / layout.canvasSize.height)
            : 0
        let canvasSize = CGSize(width: layout.canvasSize.width * scale, height: layout.canvasSize.height * scale)
        ZStack(alignment: .topLeading) {
            switch settings.fill {
            case .color:
                Rectangle()
                    .fill(Color(settings.borderColor))
            case .blur:
                Image(uiImage: thumbnail.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .blur(radius: settings.blurRadius(canvasSize: canvasSize), opaque: true)
                    .clipped()
            }
            let photoSize = CGSize(width: layout.imageRect.width * scale, height: layout.imageRect.height * scale)
            let shadowBlur = settings.shadowBlur(canvasSize: canvasSize)
            // With its HDR highlights when Download keeps them (PNG can't); the border stays SDR either way.
            let hdrImage = settings.savesHDR ? thumbnail.hdrImage : nil
            Image(uiImage: hdrImage ?? thumbnail.image)
                .resizable()
                .allowedDynamicRange(hdrImage != nil ? .high : .standard)
                .frame(width: photoSize.width, height: photoSize.height)
                .clipShape(.rect(cornerRadius: settings.cornerRadius(canvasSize: canvasSize, photoSize: photoSize)))
                // SwiftUI's shadow radius is about half of Core Graphics' blur, which the export uses.
                .shadow(color: .black.opacity(shadowBlur > 0 ? 0.5 : 0), radius: shadowBlur / 2, y: shadowBlur / 4)
                .offset(x: layout.imageRect.minX * scale, y: layout.imageRect.minY * scale)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        // The shadow stops at the canvas's edge, as in the export.
        .clipped()
        .overlay(alignment: .topLeading) {
            let rows = PhotoCaption.rows(photoItems: thumbnail.captionItems, settings: settings)
            if let placement = PhotoCaption.placement(of: rows, layout: layout) {
                ZStack(alignment: .topLeading) {
                    ForEach(placement.entries, id: \.item.field) { entry in
                        // Placed from the same boxes the export draws in, so icons stand on the text's baseline.
                        if let icon = entry.item.icon {
                            let box = placement.iconRect(for: entry)
                            CaptionIconView(icon: icon)
                                .frame(width: box.width * scale, height: box.height * scale)
                                .offset(x: box.minX * scale, y: box.minY * scale)
                        }
                        Text(entry.item.text)
                            .font(.custom(rows.font.postScriptName, fixedSize: placement.fontSize * scale))
                            .lineLimit(1)
                            .fixedSize()
                            .frame(height: entry.frame.height * scale)
                            .offset(x: (entry.frame.minX + placement.textOffset(for: entry.item)) * scale,
                                    y: entry.frame.minY * scale)
                    }
                }
                .foregroundStyle(Color(PhotoCaption.color(on: settings.borderColor, fill: settings.fill)))
                .shadow(color: settings.fill == .blur ? .black.opacity(0.5) : .clear, radius: placement.fontSize * scale * 0.2)
                .accessibilityHidden(true)
            }
        }
    }
}
