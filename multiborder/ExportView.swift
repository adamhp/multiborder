//
//  ExportView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI
import StoreKit

/// The export width presets offered as buttons below the slider.
enum ExportSize: Int, CaseIterable, Identifiable {
    case original = 0
    case small = 1024
    case medium = 2048
    case large = 4096

    var id: Self { self }

    /// Pixel width; 0 keeps the photo's own width.
    var width: Int { rawValue }

    var title: String {
        switch self {
        case .original: "Orig."
        case .small: "Sm."
        case .medium: "Med."
        case .large: "Lg."
        }
    }

    var subtitle: LocalizedStringKey { self == .original ? "~" : "\(width)px" }

    var accessibilityLabel: LocalizedStringKey { self == .original ? "Original Size" : "\(width) Pixels Wide" }
}

struct ExportView: View {
    
    @Environment(DataModel.self) private var data
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        DefaultPage {
            VStack(spacing: 12) {
                
                Spacer(minLength: 128)
                
                VStack(spacing: 16) {
                    Text(data.settings.exportWidth == 0 ? "Original" : "\(data.settings.exportWidth)px").font(.spaceMono(16))
                        .contentTransition(.numericText(value: Double(data.settings.exportWidth)))
                        .fixedSize()
                        .frame(width: 64, height: 32)
                    
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
                        Text("Orig.").font(.spaceMono(16))
                    } maximumValueLabel: {
                        Text("8192px").font(.spaceMono(16))
                    }
                    .accessibilityValue(data.settings.exportWidth == 0 ? "Original" : "\(data.settings.exportWidth) pixels")
                    .sensoryFeedback(.selection, trigger: data.settings.exportWidth)
                    .frame(height: 32)
                    
                    HStack(spacing: 8) {
                        ForEach(ExportSize.allCases) { size in
                            let isChosen = data.settings.exportWidth == size.width
                            Button {
                                data.settings.exportWidth = size.width
                            } label: {
                                VStack {
                                    Text(size.title).font(.spaceMono(16)).foregroundStyle(isChosen ? .white : .stone200)
                                    Text(size.subtitle).font(.spaceMono(14)).foregroundStyle(isChosen ? .stone200 : .stone400)
                                }
                                .padding(.vertical, 4)
                                .frame(minWidth: 80, minHeight: 48)
                                // The chosen size is tinted like the active tab.
                                .actionBackground(tint: isChosen ? .accent.opacity(0.5) : .stone700)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(size.accessibilityLabel)
                            .accessibilityAddTraits(isChosen ? .isSelected : [])
                            .animation(.interactiveSpring, value: isChosen)
                        }
                    }
                    .glassGroup()
                }
                // Keeps the paged TabView from swiping while the slider and buttons are in use.
                .blocksSwipe(true)
                .padding(.horizontal, 48)
                
                Spacer()
                VStack {
                    VStack {
                        if data.saveStatus == .saving {
                            ProgressView(value: data.exportProgress).padding(.horizontal, 32).tint(.accent).animation(.easeIn(duration: 1), value: data.exportProgress)
                        }
                    }.frame(height: 32).padding(.horizontal, 32)
                    HStack(spacing: 12) {
                        DownloadButton()
                        ShareButton()
                    }
                    .glassGroup()
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
                        .font(.spaceMono(16))
                        .foregroundStyle(.stone200)
                    Text("and consider leaving a review")
                        .font(.spaceMono(11))
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
    @Environment(\.requestReview) private var requestReview
    
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
                sized {
                    Text("Download")
                    Image(systemName: "arrow.down")
                }
                .foregroundStyle(.stone100)
                .actionBackground()
            case .saving:
                sized {
                    Text("Downloading")
                    ProgressView()
                }
                .foregroundStyle(.stone400)
                .actionBackground()
            case .success:
                sized {
                    Text("Saved")
                    Image(systemName: "checkmark")
                }
                .foregroundStyle(.green)
                .actionBackground(tint: .green.opacity(0.5))
                .task {
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    data.resetSaveStatus()
                    // Ask once the confirmation is gone, so the prompt doesn't cover it.
                    if data.isReviewRequestDue {
                        data.recordReviewRequest()
                        requestReview()
                    }
                }
            case .failed:
                sized {
                    Text("Failed")
                    Image(systemName: "exclamationmark.triangle")
                }
                .foregroundStyle(.orange)
                .actionBackground(tint: .orange.opacity(0.5))
        }
    }

    /// Grows with Dynamic Type instead of clipping at a fixed size.
    private func sized(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 8, content: content)
            .font(.spaceMono(18))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minWidth: 200, minHeight: 52)
    }
}

/// Opens the share sheet with every photo in the batch. Each photo is rendered when
/// the chosen destination asks for it, so nothing is rendered just by opening the sheet.
struct ShareButton: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        let settings = data.settings
        let photos = data.attachments.enumerated().map { index, attachment in
            BorderedPhoto(item: attachment.item, settings: settings, number: index + 1)
        }
        ShareLink(items: photos) { photo in
            SharePreview("Photo \(photo.number)")
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.stone100)
                .frame(minWidth: 52, minHeight: 52)
                .actionBackground()
        }
        .buttonStyle(.plain)
        .disabled(photos.isEmpty)
        .accessibilityLabel(photos.count == 1 ? "Share Photo" : "Share Photos")
    }
}

private extension View {
    /// The raised background of the export page's buttons: Liquid Glass tinted `tint` on iOS 26, a flat fill before.
    @ViewBuilder func actionBackground(tint: Color = .stone700) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 12))
        } else {
            background(tint, in: .rect(cornerRadius: 12))
        }
    }

    /// Groups neighbouring glass buttons so they render and blend as one set on iOS 26.
    @ViewBuilder func glassGroup() -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer { self }
        } else {
            self
        }
    }
}
