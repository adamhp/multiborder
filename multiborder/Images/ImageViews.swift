//
//  Images.swift
//  multiborder
//
//  Created by Adam Pearce on 9/5/24.
//

import SwiftUI

struct ImageStack: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        @Bindable var data = data
        Group {
            if data.attachments.isEmpty {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(96)
                    .opacity(0.1)
                    .foregroundStyle(.accent)
            } else {
                CardStack(data.attachments, currentIndex: $data.currentIndex) { imageAttachment in
                    ImageContainerView(imageAttachment: imageAttachment)
                }
                .padding(8)
                .accessibilityLabel("Photo")
                .accessibilityValue(accessibilityValue)
                // Re-run when the visible card or the number of cards changes.
                .task(id: [data.currentIndex, data.attachments.count]) {
                    await data.loadThumbnails(around: data.currentIndex)
                }
            }
        }
        // A new selection starts at the first photo. Only a change resets it, so switching
        // between the Select and Edit pages keeps the current card.
        .onChange(of: data.attachments.isEmpty) { _, isEmpty in
            if !isEmpty {
                data.currentIndex = 0
            }
        }
    }

    private var accessibilityValue: String {
        let position = "\(data.currentIndex + 1) of \(data.attachments.count)"
        guard data.attachments.indices.contains(data.currentIndex) else { return position }
        switch data.attachments[data.currentIndex].thumbnail {
        case .failed: return position + ", couldn't be loaded"
        case .unloaded, .loading: return position + ", loading"
        case .loaded: return position
        }
    }
}

struct ImageContainerView: View {

    @Environment(DataModel.self) private var data
    let imageAttachment: ImageAttachment

    var body: some View {
        ZStack {
            switch imageAttachment.thumbnail {
            case .unloaded:
                EmptyView()
            case .loading:
                ProgressView()
            case .loaded(let thumbnail):
                GeometryReader { geo in
                    BorderedImage(thumbnail: thumbnail, settings: data.settings, containerSize: geo.size)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityLabel("Photo couldn't be loaded")
            }
        }
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
            Image(uiImage: thumbnail.image)
                .resizable()
                .frame(width: layout.imageRect.width * scale, height: layout.imageRect.height * scale)
                .offset(x: layout.imageRect.minX * scale, y: layout.imageRect.minY * scale)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
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
