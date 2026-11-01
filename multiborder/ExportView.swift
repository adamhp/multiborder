//
//  ExportView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct ExportView: View {
    
    @Environment(DataModel.self) private var data
    @Environment(\.openURL) private var openURL
    
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
                    Text(data.settings.exportWidth == 0 ? "Original" : "\(data.settings.exportWidth)px").font(Font.custom("SpaceMono-Regular", size: 16))
                        .contentTransition(.numericText(value: Double(data.settings.exportWidth)))
                        .fixedSize()
                        .frame(width: 64, height: 32)
                        .gesture(DragGesture())
                    
                    Slider(
                        value: Binding(
                            get: { Double(data.settings.exportWidth) },
                            set: { newVal in
                                withAnimation {
                                    data.settings.exportWidth = Int(newVal)
                                }
                            }),
                        in: 0...8192,
                        step: 128
                    ) {
                        Text("Export Width")
                    } minimumValueLabel: {
                        Text("Orig.").font(Font.custom("SpaceMono-Regular", size: 16))
                    } maximumValueLabel: {
                        Text("8192px").font(Font.custom("SpaceMono-Regular", size: 16))
                    }
                    .accessibilityValue(data.settings.exportWidth == 0 ? "Original" : "\(data.settings.exportWidth) pixels")
                    .sensoryFeedback(.selection, trigger: data.settings.exportWidth)
                    .frame(height: 32)
                    
                    HStack(spacing: 8) {
                        ForEach(sizes, id: \.self.0) { size in
                            Button {
                                data.settings.exportWidth = size.1
                            } label: {
                                VStack {
                                    Text("\(size.0)").font(Font.custom("SpaceMono-Regular", size: 16)).foregroundStyle(.stone200)
                                    Text(size.1 == 0 ? "~" : "\(size.1)px").font(Font.custom("SpaceMono-Regular", size: 14)).foregroundStyle(.stone400)
                                }
                                .padding(.vertical, 4)
                                .frame(minWidth: 80, minHeight: 48)
                                .background(.stone700)
                                .clipShape(.rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(size.1 == 0 ? "Original Size" : "\(size.1) Pixels Wide")
                            .accessibilityAddTraits(data.settings.exportWidth == size.1 ? .isSelected : [])
                        }
                    }
                    .gesture(DragGesture())
                }
                .gesture(DragGesture())
                .padding(.horizontal, 48)
                
                Spacer()
                VStack {
                    VStack {
                        if data.saveStatus == .saving {
                            ProgressView(value: data.exportProgress).padding(.horizontal, 32).tint(.accent).animation(.easeIn(duration: 1), value: data.exportProgress)
                        }
                    }.frame(height: 32).padding(.horizontal, 32)
                    DownloadButton()
                }.frame(minHeight: 84)
                Spacer()
                
                VStack(spacing: 32) {
                    KofiButton()
                    if case .failed(let message) = data.saveStatus {
                        Text(message).foregroundStyle(.orange)
                    }
                    if !data.attachments.isEmpty {
                        Button {
                            // Undocumented scheme: best effort, openURL simply fails if it is unavailable.
                            if let url = URL(string: "photos-redirect://") {
                                openURL(url)
                            }
                            data.resetSaveStatus()
                        } label: {
                            Text("Open Photos Library")
                        }
                        Button(role: .destructive) {
                            data.clearSelection()
                            data.helpTextShown = false
                            data.selectedTab = .select
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    var body: some View {
        Link(destination: URL(string: "https://ko-fi.com/adamhp")!, label: {
            HStack(spacing: 2) {
                Image(.kofi)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Text("Support me on Ko-fi!")
                        .font(Font.custom("SpaceMono-Regular", size: 16))
                        .foregroundStyle(.stone200)
                    Text("and consider leaving a review")
                        .font(Font.custom("SpaceMono-Regular", size: 11))
                        .foregroundStyle(.stone200)
                }
                
            }
        })
        .scaleEffect(isAnimating ? 1.1 : 1)
        .animation(
            isAnimating ?
                .easeInOut(duration: 2).repeatForever(autoreverses: true) :
                    .default,
            value: isAnimating
        )
        .onChange(of: reduceMotion, initial: true) {
            isAnimating = !reduceMotion
        }
    }
}

struct DownloadButton: View {
    
    @Environment(DataModel.self) private var data
    
    var body: some View {
        Button {
            switch data.saveStatus {
                case .unsaved, .failed:
                    data.startExport()
                default:
                    return
            }
        } label: {
            label
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: data.saveStatus == .success)
        .sensoryFeedback(.warning, trigger: data.saveStatus.isFailed)
        .sensoryFeedback(.impact, trigger: data.saveStatus == .saving)
        .onChange(of: data.saveStatus) { _, status in
            // The result is only shown briefly, so tell VoiceOver users too.
            switch status {
            case .success: AccessibilityNotification.Announcement("Saved to Photos").post()
            case .failed(let message): AccessibilityNotification.Announcement(message).post()
            case .unsaved, .saving: break
            }
        }
    }

    @ViewBuilder private var label: some View {
        switch data.saveStatus {
            case .unsaved:
                let content = sized {
                    Text("Download")
                    Image(systemName: "arrow.down")
                }
                .foregroundStyle(.stone100)
                Group {
                    if #available(iOS 26, *) {
                        content
                            .glassEffect(.regular.tint(.stone700).interactive(), in: .rect(cornerRadius: 12))
                    } else {
                        content
                            .background(.stone700, in: .rect(cornerRadius: 12))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accent.opacity(0.5), lineWidth: 4)
                )
            case .saving:
                sized {
                    Text("Downloading")
                    ProgressView()
                }
                .foregroundStyle(.stone400)
                .background(.stone700, in: .rect(cornerRadius: 12))
            case .success:
                sized {
                    Text("Saved")
                    Image(systemName: "checkmark")
                }
                .foregroundStyle(.green)
                .background(.green.opacity(0.5), in: .rect(cornerRadius: 12))
                .task {
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    data.resetSaveStatus()
                }
            case .failed:
                sized {
                    Text("Failed")
                    Image(systemName: "exclamationmark.triangle")
                }
                .foregroundStyle(.orange)
                .background(.orange.opacity(0.5), in: .rect(cornerRadius: 12))
        }
    }

    /// Grows with Dynamic Type instead of clipping at a fixed size.
    private func sized(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 8, content: content)
            .font(Font.custom("SpaceMono-Regular", size: 18))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minWidth: 200, minHeight: 52)
    }
}
