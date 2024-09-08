//
//  ExportView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct ExportSize {
    var label: String
    var bytes: Int
}

extension ExportSize: Identifiable {
    var id: String {
        label
    }
}

struct ExportView: View {
    
    @EnvironmentObject private var data: DataModel
    
    let sizes: [ExportSize] = [
        ExportSize(label: "1024", bytes: 1024),
        ExportSize(label: "2048", bytes: 2048),
        ExportSize(label: "4096", bytes: 4096),
        ExportSize(label: "Original", bytes: 0)
    ]
    
    var body: some View {
        DefaultPage {
            VStack(spacing: 0) {
                Spacer()
                Grid(alignment: .center, horizontalSpacing: 16, verticalSpacing: 24) {
                    ForEach(sizes, id: \.label) { size in
                        GridRow {
                            Text(String(size.label))
                                .frame(width: 192, height: 64)
                                .font(Font.custom("SpaceMono-Regular", size: 18))
                                .foregroundColor(.stone100)
                                .background(Color(.stone700))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            DownloadButton(size: size.bytes)
//                            ShareButton(size: size.bytes)
                        }
                    }
                }
                Spacer()
                Text("Support me on Kofi!")
                .frame(height: 128)
            }
        }
    }
}

struct DownloadButton: View {
    
    let size: Int
    @EnvironmentObject private var data: DataModel
    
    var body: some View {
        Button {
            let _ = print("saving!")
            data.renderAndSave(size: size)
        } label: {
            VStack {
                Image(systemName: "arrow.down")
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            }
            .frame(width: 64, height: 64)
            .foregroundColor(.stone400)
            .background(.stone700)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ShareButton: View {
    
    let size: Int
    @EnvironmentObject private var data: DataModel
    
    var body: some View {
        ShareLink(items: data.rendered, subject: nil, message: nil, preview: { _ in
            SharePreview("Test", image: data.rendered.first ?? Image(systemName: "square.and.arrow.up"))
        }, label: {
//            Button {
//                let _ = print("sharing!")
//                data.render(size: size)
//            } label: {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                }
                .frame(width: 64, height: 64)
                .foregroundColor(.stone400)
                .background(.stone700)
                .clipShape(RoundedRectangle(cornerRadius: 12))
//            }
        })
    }
}
