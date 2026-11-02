//
//  SettingsView.swift
//  multiborder
//
//  How exports are saved, and whether the share sheet asks first.
//

import SwiftUI

struct SettingsView: View {

    @Environment(DataModel.self) private var data
    /// Stored the other way round (true skips the question), as the share extension reads it.
    @AppStorage(shareExtensionSkipsIntroKey, store: .appGroup) private var skipsShareIntro = false
    @State private var albumAccessDenied = false

    var body: some View {
        DefaultPage {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Saving") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                ForEach(ExportFormat.allCases) { format in
                                    Button {
                                        data.settings.exportFormat = format
                                    } label: {
                                        Text(format.title).font(.spaceMono(16))
                                    }
                                    .buttonStyle(AspectRatioButton(active: data.settings.exportFormat == format))
                                    .accessibilityLabel(format == .original ? "Original Format" : "\(format.title)")
                                    .accessibilityAddTraits(data.settings.exportFormat == format ? .isSelected : [])
                                }
                            }
                            .sensoryFeedback(.selection, trigger: data.settings.exportFormat)
                            footnote(formatFootnote)
                        }
                        toggle("Save to “\(PhotoLibrary.albumTitle)” album", systemImage: "rectangle.stack",
                               isOn: albumBinding,
                               footnote: albumAccessDenied
                                   ? "Allow full or limited access to Photos in the Settings app to use the album."
                                   : "Also adds each download to an album called “\(PhotoLibrary.albumTitle)”.")
                        toggle("Keep original date", systemImage: "calendar",
                               isOn: Bindable(data).settings.keepsOriginalDate,
                               footnote: data.settings.keepsOriginalDate
                                   ? "Downloads are dated when the photo was taken, next to the original."
                                   : "Downloads are dated now, at the top of Recents.")
                    }

                    section("Share Sheet") {
                        toggle("Confirm settings", systemImage: "questionmark.bubble",
                               isOn: Binding(get: { !skipsShareIntro }, set: { skipsShareIntro = !$0 }),
                               footnote: "Ask before adding borders from the share sheet, with a summary of the settings that will be used.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // Four format buttons must fit one row; beyond this size they would truncate.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var formatFootnote: LocalizedStringKey {
        switch data.settings.exportFormat {
        case .original: "HEIC and PNG photos keep their format; others are saved as JPEG."
        case .jpeg: "Works everywhere."
        case .heic: "About half the size of JPEG, at the same quality."
        case .png: "Lossless, and much larger."
        }
    }

    /// Turning the album on first asks for the access it needs, and stays off if it isn't given.
    private var albumBinding: Binding<Bool> {
        Binding(
            get: { data.settings.savesToAlbum },
            set: { isOn in
                guard isOn else {
                    data.settings.savesToAlbum = false
                    return
                }
                Task {
                    let allowed = await PhotoLibrary.requestAlbumAccess()
                    albumAccessDenied = !allowed
                    data.settings.savesToAlbum = allowed
                }
            })
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.spaceMono(14))
                .foregroundStyle(.stone400)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func toggle(_ title: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>,
                        footnote text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isOn) {
                Label {
                    Text(title).font(.spaceMono(16))
                } icon: {
                    Image(systemName: systemImage).frame(width: 32)
                }
            }
            .tint(.accent)
            .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
            footnote(text)
        }
    }

    private func footnote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.spaceMono(12))
            .foregroundStyle(.stone400)
            .fixedSize(horizontal: false, vertical: true)
    }
}
