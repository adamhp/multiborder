//
//  Images.swift
//  multiborder
//
//  Created by Adam Pearce on 9/5/24.
//

import SwiftUI

struct ImageStack: View {
    
    @EnvironmentObject private var data: DataModel
    
    var body: some View {
        if data.attachments.isEmpty {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .padding(96)
                .opacity(0.1)
                .foregroundColor(.accent)
        } else {
            CardStack(data.attachments, currentIndex: $data.currentIndex) { imageAttachment in
                ImageContainerView(imageAttachment: imageAttachment)
            }
            .padding(8)
            .task {
                data.currentIndex = 0
            }
        }
    }
}

struct ImageContainerView: View {
    
    @EnvironmentObject private var data: DataModel
    @ObservedObject var imageAttachment: DataModel.ImageAttachment
    
    var body: some View {
        ZStack {
            switch imageAttachment.status.thumbnailStatus {
                case .unloaded:
                    EmptyView()
                case .loading:
                    ProgressView()
                case .finished(_):
                    GeometryReader { geo in
                        Rectangle()
                            .foregroundColor(data.desiredBorderColor)
                            .aspectRatio(data.desiredAspectRatio == -1 ? (imageAttachment.originalImageWidth! / imageAttachment.originalImageHeight!) : data.desiredAspectRatio, contentMode: .fit)
                            .overlay(ImageAttachmentView(imageAttachment: imageAttachment))
                            .position(x: geo.frame(in: .local).midX, y: geo.frame(in: .local).midY)
                            .onAppear {
                                if data.originalContainerWidth == 0 {
                                    data.originalContainerWidth = geo.size.width
                                }
                            }
                    }
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
            }
        }
    }
       
}

struct ImageAttachmentView: View {
    
    @EnvironmentObject private var data: DataModel
    @ObservedObject var imageAttachment: DataModel.ImageAttachment
    
    var body: some View {
        if let thumbnail = imageAttachment.imageThumbnail {
            thumbnail
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(data.desiredPadding)
        } else {
            EmptyView()
        }
    }
}
