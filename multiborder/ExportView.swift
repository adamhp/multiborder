//
//  ExportView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct ExportView: View {
    
    @EnvironmentObject private var data: DataModel
    
    @State private var showSuccess = false
    @State private var showFailure = false
    
    func reset() {
        showSuccess = false
        data.resetSizeResults()
    }
    
    var body: some View {
        DefaultPage {
            VStack(spacing: 12) {
                Spacer()
                Grid(alignment: .center, horizontalSpacing: 16, verticalSpacing: 24) {
                    ForEach(data.supportedSizes, id: \.label) { size in
                        GridRow {
                            Text(String(size.label))
                                .frame(width: 192, height: 52)
                                .font(Font.custom("SpaceMono-Regular", size: 18))
                                .foregroundColor(.stone100)
                                .background(Color(.stone700))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            DownloadButton(size: size, showSuccess: $showSuccess, showFailure: $showFailure)
//                            ShareButton(size: size.bytes)
                        }
                    }
                }
                KofiButton()
                Spacer()
                if data.selection.count > 0 {
                    Button(role: .destructive) {
                        data.clearSelection()
                        reset()
                        data.helpTextShown = false
                        data.selectedTab = 0
                    } label: {
                        Text("Start Over")
                    }
                }
            }
            .alert(
                "Success!",
                isPresented: $showSuccess,
                presenting: {}
            ) { _ in
                Button {
                    UIApplication.shared.open(URL(string: "photos-redirect://")!)
                    reset()
                } label: {
                    Text("Open Photos Library")
                }
                Button(role: .destructive) {
                    data.clearSelection()
                    reset()
                    data.selectedTab = 0
                } label: {
                    Text("Start Over")
                }
                Button(role: .cancel) {
                    reset()
                } label: {
                    Text("Dismiss")
                }
            } message: { _ in
            }
            .alert(
                "Error",
                isPresented: $showFailure,
                presenting: {}
            ) { _ in
                Button(role: .cancel) {
                    reset()
                } label: {
                    Text("Dismiss")
                }
            } message: { _ in
                Text("\(data.hasError ? data.error!.localizedDescription : "Unknown error").")
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
    
    let size: ExportSize
    
    @EnvironmentObject private var data: DataModel
    @Binding var showSuccess: Bool
    @Binding var showFailure: Bool
    
    var body: some View {
        Button {
            
        } label: {
            DownloadProgress(size: size, showSuccess: $showSuccess, showFailure: $showFailure)
        }
    }
}

enum DownloadState {
    case none
    case loading
    case success
    case failure
}

struct DownloadProgress: View {
    
    var size: ExportSize
    
    @EnvironmentObject var data: DataModel
    @Binding var showSuccess: Bool
    @Binding var showFailure: Bool
    @State var state: DownloadState = .none
    
    var body: some View {
        ZStack {
            switch state {
                case .none:
                    VStack {
                        Image(systemName: "arrow.down")
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                    }
                    .frame(width: 52, height: 52)
                    .foregroundColor(.stone400)
                    .background(.stone700)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                case .loading:
                    VStack {
                        ProgressView()
                            .scaledToFit()
                            .padding(20)
                            .onAppear(perform: {
                                Task {
                                    await data.renderAndSave(size)
                                }
                            })
                    }
                    .frame(width: 52, height: 52)
                    .foregroundColor(.stone400)
                    .background(.stone700)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                case .success:
                    VStack {
                        Image(systemName: "checkmark")
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                            .foregroundColor(.green)
                    }
                    .frame(width: 52, height: 52)
                    .foregroundColor(.green)
                    .background(.green.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                            .foregroundColor(.green)
                    }
                    .frame(width: 52, height: 52)
                    .foregroundColor(.orange)
                    .background(.orange.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sensoryFeedback(.success, trigger: self.state == .success)
        .sensoryFeedback(.warning, trigger: self.state == .failure)
        .sensoryFeedback(.impact, trigger: self.state == .loading)
        .onChange(of: data.attachments.count, {
            if data.attachments.count == 0 {
                self.state = .none
            }
        })
        .onChange(of: data.saveResults[size.label], {
            if data.saveResults[size.label] == data.attachments.count {
                if data.saveFailures[size.label]! > 0 {
                    self.state = .failure
                    showFailure = true
                } else {
                    self.state = .success
                    showSuccess = true
                }
            }
        })
    }
}


//struct ShareButton: View {
//    
//    let size: ExportSize
//    
//    @EnvironmentObject private var data: DataModel
//    
//    init(_ size: ExportSize) {
//        self.size = size
//    }
//    
//    var body: some View {
//        ShareLink(items: data.rendered, subject: nil, message: nil, preview: { _ in
//            SharePreview("Test", image: data.rendered.first ?? Image(systemName: "square.and.arrow.up"))
//        }, label: {
////            Button {
////                data.render(size: size)
////            } label: {
//                VStack {
//                    Image(systemName: "square.and.arrow.up")
//                        .resizable()
//                        .scaledToFit()
//                        .padding(24)
//                }
//                .frame(width: 64, height: 64)
//                .foregroundColor(.stone400)
//                .background(.stone700)
//                .clipShape(RoundedRectangle(cornerRadius: 12))
////            }
//        })
//    }
//}

