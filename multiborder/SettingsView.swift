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
                        toggle("Save to album", systemImage: "rectangle.stack",
                               isOn: albumBinding,
                               footnote: albumAccessDenied
                                   ? "Allow full or limited access to Photos in the Settings app to use an album."
                                   : "Also adds each download to “\(data.settings.albumName)”.")
                        if data.settings.savesToAlbum {
                            AlbumMenu()
                                .padding(.leading, 40)
                                .transition(.opacity)
                        }
                        toggle("Keep original date", systemImage: "calendar",
                               isOn: Bindable(data).settings.keepsOriginalDate,
                               footnote: data.settings.keepsOriginalDate
                                   ? "Downloads are dated when the photo was taken, next to the original."
                                   : "Downloads are dated now, at the top of Recents.")
                        // Gain maps are only read and written from iOS 18.
                        if #available(iOS 18, *) {
                            toggle("Keep HDR", systemImage: "sun.max",
                                   isOn: Bindable(data).settings.keepsHDR,
                                   footnote: hdrFootnote)
                        }
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

    private var hdrFootnote: LocalizedStringKey {
        if !data.settings.keepsHDR {
            "HDR photos are saved at standard brightness."
        } else if !data.settings.savesHDR {
            "PNG can’t hold HDR, so photos are saved at standard brightness. Choose another format to keep it."
        } else {
            "HDR photos keep their bright highlights on HDR screens. The border stays at standard brightness."
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
                    withAnimation {
                        data.settings.savesToAlbum = allowed
                    }
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

/// Chooses the album downloads go into: one of the user's albums, or a new one they name. Under limited
/// access iOS may list no albums, which leaves naming a new one (or reusing one by typing its name).
private struct AlbumMenu: View {

    @Environment(DataModel.self) private var data
    @Environment(\.scenePhase) private var scenePhase
    @State private var albums = [PhotoLibrary.Album]()
    @State private var isNaming = false
    @State private var newName = ""
    @State private var creationFailed = false

    var body: some View {
        let settings = data.settings
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                ForEach(albums) { album in
                    Button {
                        choose(album)
                    } label: {
                        if isChosen(album) {
                            Label(album.title, systemImage: "checkmark")
                        } else {
                            Text(album.title)
                        }
                    }
                }
                if !albums.isEmpty {
                    Divider()
                }
                Button("New Album…", systemImage: "plus") {
                    newName = ""
                    isNaming = true
                }
            } label: {
                HStack {
                    Text(settings.albumName)
                        .font(.spaceMono(16))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.stone400)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.stone700, in: .rect(cornerRadius: 12))
            }
            .accessibilityLabel("Album")
            .accessibilityValue(settings.albumName)
            if creationFailed {
                Text("Couldn't create that album.")
                    .font(.spaceMono(12))
                    .foregroundStyle(.orange)
            }
        }
        .alert("New Album", isPresented: $isNaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                Task { await create() }
            }
        } message: {
            Text("If you already have an album with this name, downloads go into it.")
        }
        .onAppear(perform: refresh)
        // Picks up albums made or renamed in Photos while the app was in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    /// The chosen album by its identifier, or by name before one was chosen from the list.
    private func isChosen(_ album: PhotoLibrary.Album) -> Bool {
        data.settings.albumID.map { $0 == album.id } ?? (album.title == data.settings.albumName)
    }

    private func choose(_ album: PhotoLibrary.Album) {
        creationFailed = false
        data.settings.albumID = album.id
        data.settings.albumName = album.title
    }

    private func create() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let album = try? await PhotoLibrary.findOrCreateAlbum(named: name) {
            choose(album)
            refresh()
        } else {
            creationFailed = true
        }
    }

    /// Reloads the list, and follows the chosen album if it was renamed in Photos.
    private func refresh() {
        albums = PhotoLibrary.albums()
        if let id = data.settings.albumID, let title = PhotoLibrary.albumTitle(id: id), title != data.settings.albumName {
            data.settings.albumName = title
        }
    }
}
