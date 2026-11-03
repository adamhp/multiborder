//
//  EditingScreen.swift
//  EditBorderExtension
//
//  The app's Edit page for the one photo Photos is editing.
//

import SwiftUI

/// What the screen shows, filled in by `PhotoEditingViewController` as Photos hands over the photo.
@MainActor @Observable final class EditingSession {

    /// Set once Photos has handed over the photo and its settings are known.
    var editor: BorderEditor?
    var preview = ThumbnailState.loading
    /// The photo's latest edit isn't a border, so the border goes on top of it.
    var hasOtherEdits = false
    /// Done was tapped and the full-size photo is being drawn.
    var isSaving = false
}

struct EditingScreen: View {

    let session: EditingSession

    var body: some View {
        ZStack {
            if let editor = session.editor {
                VStack(spacing: 0) {
                    if session.hasOtherEdits {
                        Text("This photo has other edits. The border is added on top of them. To change a border added earlier, revert the photo in Photos first.")
                            .font(.spaceMono(12))
                            .foregroundStyle(.stone400)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                    EditView {
                        ThumbnailPreview(state: session.preview, settings: editor.settings)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .environment(editor)
                .disabled(session.isSaving)
            } else {
                ProgressView()
            }

            if session.isSaving {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Adding border…").font(.spaceMono(14))
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(.stone800), Color(.stone900)], startPoint: .top, endPoint: .bottom))
        .preferredColorScheme(.dark)
        .environment(\.font, .spaceMono(14))
    }
}
