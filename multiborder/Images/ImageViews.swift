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
            ThumbnailPreview(state: imageAttachment.thumbnail, settings: data.settings)
        }
    }
}
