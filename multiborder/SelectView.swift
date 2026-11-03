//
//  SelectView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI
import PhotosUI

struct SelectView: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        DefaultPage {
            // The picker shows until it hands over a batch, and again once the batch is cleared.
            if data.attachments.isEmpty {
                PickerPage()
            } else {
                StackPage()
            }
        }
        .animation(.default, value: data.attachments.isEmpty)
        .sensoryFeedback(.success, trigger: data.attachments.isEmpty) { wasEmpty, isEmpty in
            wasEmpty && !isEmpty
        }
    }
}

/// The system photo picker embedded in the page. People select photos by tapping or by
/// dragging across them, then confirm with the picker's own check mark, which hands the
/// batch over in one go.
private struct PickerPage: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        @Bindable var data = data
        VStack(spacing: 16) {
            PhotosPicker(
                selection: $data.selection,
                // Drag-to-select only works with this mode: it didn't with .continuousAndOrdered, with the
                // top bar showing or hidden, or with .ordered and the top bar hidden (iPhone 16 Pro, iOS 26–27).
                // So the app only learns the selection when the check mark hands it over, and can't clear it before.
                selectionBehavior: .default,
                matching: .images,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                EmptyView()
            }
            .photosPickerStyle(.inline)
            // The top bar holds the picker's check mark, so it stays visible. Disabling the
            // selection actions hides its cancel X, which does nothing in an embedded picker,
            // and keeps the check mark (as in Apple's inline picker sample).
            .photosPickerDisabledCapabilities([.selectionActions, .stagingArea])
            .ignoresSafeArea(edges: .top)

            // Below the picker rather than over it, so it's readable.
            if data.helpTextShown {
                Text("Select some photos first!")
                    .font(.spaceMono(16))
                    .foregroundStyle(.accent)
                    .frame(height: 48)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: data.helpTextShown)
        .task(id: data.helpTextShown) {
            guard data.helpTextShown else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            data.helpTextShown = false
        }
    }
}

/// The picked photos as a card stack. The tab bar's Clear tab removes them.
private struct StackPage: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("\(data.currentIndex+1) of \(data.attachments.count)")
                .contentTransition(.numericText(value: Double(data.currentIndex)))
                .font(.spaceMono(14))
                .foregroundStyle(.accent)
                .padding(.top, 16)
            Text("(Preview Resolution)")
                .font(.spaceMono(12))
                .foregroundStyle(.stone500)
                .padding(.top, 16)
            Spacer()
            ImageStack()
            Spacer()
        }
    }
}
