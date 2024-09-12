//
//  ExportView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct ExportView: View {
    
    @EnvironmentObject private var data: DataModel
    
    func reset() {
        data.error = nil
        data.saveStatus = .unsaved
    }
    
    let sizes = [
        ("Orig.", 0),
        ("Sm.", 1024),
        ("Med.", 2048),
        ("Lg.", 4096)
    ]
    
    var body: some View {
        DefaultPage {
            VStack(spacing: 12) {
                
                Spacer(minLength: 128)
                
                VStack(spacing: 16) {
                    Text(data.desiredSize == 0 ? "Original" : "\(Int(data.desiredSize))px").font(Font.custom("SpaceMono-Regular", size: 16))
                        .contentTransition(.numericText(value: Double(data.desiredSize)))
                        .fixedSize()
                        .frame(width: 64, height: 32)
                        .gesture(DragGesture())
                    
                    Slider(
                        value: Binding(
                            get: { CGFloat(data.desiredSize) },
                            set: { newVal in
                                withAnimation {
                                    data.setDesiredSize(Int(newVal))
                                }
                            }),
                        in: 0...8192,
                        step: 128
                    ) {
                    } minimumValueLabel: {
                        Text("Orig.").font(Font.custom("SpaceMono-Regular", size: 16))
                    } maximumValueLabel: {
                        Text("8192px").font(Font.custom("SpaceMono-Regular", size: 16))
                    }
                    .sensoryFeedback(.selection, trigger: data.desiredSize)
                    .frame(height: 32)
                    
                    HStack(spacing: 8) {
                        ForEach(sizes, id: \.self.0, content: { size in
                            VStack {
                                Text("\(size.0)").font(Font.custom("SpaceMono-Regular", size: 16)).foregroundColor(.stone200)
                                Text(size.0 == "Orig." ? "~" : "\(size.1)px").font(Font.custom("SpaceMono-Regular", size: 14)).foregroundColor(.stone400)
                            }
                            .onTapGesture {
                                data.setDesiredSize(size.1)
                            }
                            .frame(width: 80, height: 48)
                            .foregroundColor(.stone400)
                            .background(.stone700)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        })
                    }
                    .gesture(DragGesture())
                }
                .gesture(DragGesture())
                .padding(.horizontal, 48)
                
                Spacer()
                
                DownloadButton()
                
                Spacer()
                
                VStack(spacing: 32) {
                    KofiButton()
                    if data.hasError {
                        Text(data.error!.localizedDescription)
                    } else if data.selection.count > 0 {
                        Button {
                            UIApplication.shared.open(URL(string: "photos-redirect://")!)
                            reset()
                        } label: {
                            Text("Open Photos Library")
                        }
                        Button(role: .destructive) {
                            data.clearSelection()
                            reset()
                            data.helpTextShown = false
                            data.selectedTab = 0
                        } label: {
                            Text("Start Over")
                        }
                    }
                }.padding(.bottom, 8)
            }
        }
    }
}

struct KofiButton: View {
    @State var isAnimating = false
    var body: some View {
        Link(destination: URL(string: "https://ko-fi.com/adamhp")!, label: {
            HStack(spacing: 2) {
                Image(.kofi)
                    .resizable()
                    .frame(width: 40, height: 40)
                Text("Support me on Ko-fi!")
                    .font(Font.custom("SpaceMono-Regular", size: 16))
                    .foregroundColor(.stone200)
                
            }
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
    
    @EnvironmentObject var data: DataModel
    
    var body: some View {
        ZStack {
            switch data.saveStatus {
                case .unsaved:
                    VStack {
                        HStack(spacing: 8) {
                            Text("Download").font(Font.custom("SpaceMono-Regular", size: 18))
                            Image(systemName: "arrow.down")
                                .resizable()
                                .scaledToFit()
                        }
                        .padding(20)
                    }
                    .frame(width: 200, height: 52)
                    .foregroundColor(.stone100)
                    .background(.stone700)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accent.opacity(0.5), lineWidth: 4)
                    )
                case .saving:
                    VStack {
                        HStack(spacing: 8)  {
                            Text("Downloading").font(Font.custom("SpaceMono-Regular", size: 18))
                            ProgressView()
                                .scaledToFit()
                        }
                        .padding(20)
                        
                    }
                    .frame(width: 200, height: 52)
                    .foregroundColor(.stone400)
                    .background(.stone700)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                case .success:
                    VStack {
                        HStack(spacing: 8)  {
                            Text("Saved").font(Font.custom("SpaceMono-Regular", size: 18)).foregroundColor(.green)
                            Image(systemName: "checkmark")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.green)
                        }
                        .padding(20)
                    }
                    .frame(width: 200, height: 52)
                    .foregroundColor(.green)
                    .background(.green.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failed:
                    VStack {
                        HStack(spacing: 8)  {
                            Text("Failed").font(Font.custom("SpaceMono-Regular", size: 18)).foregroundColor(.green)
                            Image(systemName: "exclamationmark.triangle")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.orange)
                        }
                        .padding(20)
                    }
                    .frame(width: 200, height: 52)
                    .foregroundColor(.orange)
                    .background(.orange.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: data.processed, {
            if data.processed == data.attachments.count {
                let failures = data.attachments.filter({ $0.status.savingStatus.isFailed })
                if failures.count > 0 {
                    data.saveStatus = .failed("Failed to save images")
                } else {
                    data.saveStatus = .success
                }
            }
        })
        .onTapGesture {
            switch data.saveStatus {
                case .unsaved:
                    data.saveStatus = .saving
                    Task {
                        await data.renderAndSave()
                    }
                default:
                    return
            }
        }
        .sensoryFeedback(.success, trigger: data.saveStatus.isSuccess)
        .sensoryFeedback(.warning, trigger: data.saveStatus.isFailed)
        .sensoryFeedback(.impact, trigger: data.saveStatus.isSaving)
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
