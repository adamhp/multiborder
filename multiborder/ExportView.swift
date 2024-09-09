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
    
    @State private var showSuccess = false
    @State private var showFailure = false
    @State private var showAlert = false
    
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
//                            ShareButton(size: size.bytes)sw
                        }
                    }
                }
                Spacer()
                KofiButton()
            }.onChange(of: data.saveSuccesses, {
                if data.attachments.count == data.saveResults && data.saveSuccesses > 0 {
                    showSuccess = true
                }
            })
            .onChange(of: data.saveFailures, {
                if data.attachments.count == data.saveResults && data.saveFailures > 0 {
                    showFailure = true
                }
            })
            .alert(
                "Success!",
                isPresented: $showSuccess,
                presenting: {}
            ) { _ in
                Button {
                    UIApplication.shared.open(URL(string: "photos-redirect://")!)
                    showSuccess = false
                    data.saveFailures = 0
                    data.saveSuccesses = 0
                    data.saveResults = 0
                } label: {
                    Text("Open Photos Library")
                }
                Button(role: .destructive) {
                    data.clearSelection()
                    data.selectedTab = 0
                    showSuccess = false
                    data.saveFailures = 0
                    data.saveSuccesses = 0
                    data.saveResults = 0
                } label: {
                    Text("Start Over")
                }
                Button(role: .cancel) {
                    showSuccess = false
                    data.saveFailures = 0
                    data.saveSuccesses = 0
                    data.saveResults = 0
                } label: {
                    Text("Dismiss")
                }
            } message: { _ in
                Text("Successfully saved \(data.saveSuccesses) photos.")
            }
            .alert(
                "Title",
                isPresented: $showFailure,
                presenting: {}
            ) { _ in
                Button(role: .cancel) {
                    showFailure = false
                    data.saveFailures = 0
                    data.saveSuccesses = 0
                    data.saveResults = 0
                } label: {
                    Text("Dismiss")
                }
            } message: { _ in
                Text("Failed to save \(data.saveFailures) photos. \(data.failureMessage).")
            }
        }
    }
}

struct KofiButton: View {
    @State var isAnimating = false
    var body: some View {
        Link(destination: URL(string: "https://ko-fi.com/adamhp")!, label: {
            HStack(spacing: 0) {
                Image(.kofi)
                    .resizable()
                    .frame(width: 40, height: 40)
                Text("Support me on Ko-fi!")
                    .font(Font.custom("SpaceMono-Regular", size: 14))
                    .foregroundColor(.stone100)
                
            }
            .padding(.horizontal, 8)
            .frame(width: 220, height: 48)
            .background(Color(.stone700))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(height: 128)
        })
        .scaleEffect(isAnimating ? 1.1 : 1)
        .animation(
            isAnimating ?
                .easeInOut(duration: 2).repeatForever(autoreverses: true) :
                    .default,
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

struct DownloadButton: View {
    
    let size: Int
    @EnvironmentObject private var data: DataModel
    
    var body: some View {
        Button {
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

