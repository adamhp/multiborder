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
        @Bindable var data = data
        DefaultPage {
            VStack(spacing: 0) {
                Spacer()
                if data.attachments.count > 0 {
                    Text("\(data.currentIndex+1) of \(data.attachments.count)")
                        .contentTransition(.numericText(value: Double(data.currentIndex)))
                        .font(Font.custom("SpaceMono-Regular", size: 14))
                        .foregroundStyle(.accent)
                        .padding(.top, 16)
                    Text("(Preview Resolution)")
                        .contentTransition(.numericText(value: Double(data.currentIndex)))
                        .font(Font.custom("SpaceMono-Regular", size: 12))
                        .foregroundStyle(.stone500)
                        .padding(.top, 16)
                }
                Spacer()
                ImageStack()
                Spacer()
                if data.attachments.isEmpty {
                    PhotosPicker(
                        selection: $data.selection,
                        matching: .images,
                        preferredItemEncoding: .current,
                        photoLibrary: .shared()
                    ) {
                        // The picker's label closure is not main-actor isolated, so it reads the model in its own view.
                        SelectPickerLabel()
                    }
                    .accessibilityLabel("Select Photos")
                    .frame(height: 64)
                } else {
                    ClearButton(data: data)
                        .frame(height: 64)
                }
            }
            .sensoryFeedback(.success, trigger: !data.selection.isEmpty)
            .task(id: data.helpTextShown) {
                guard data.helpTextShown else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                withAnimation {
                    data.helpTextShown = false
                }
            }
        
        }
    }
}

struct SelectPickerLabel: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        ZStack {
            if data.helpTextShown {
                Text("Select some photos first!")
                    .kerning(0)
                    .animation(.easeInOut(duration:1), value: data.helpTextShown)
                    .font(Font.custom("SpaceMono-Regular", size: 16))
                    .foregroundStyle(.accent)
                    .padding(.bottom, 128)
            }
            SelectButton().animation(.easeInOut(duration: 0.5), value: data.selection.isEmpty)
        }
    }
}

struct SelectButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.accent.opacity(0.2))
                .frame(width: 64, height: 64)
            Image(systemName: "plus")
                .foregroundStyle(.accent)
                .font(.system(size: 32, weight: .semibold))
        }
    }
}

struct ClearButton: View {
    
    let data: DataModel
    
    @State private var tap = false
    
    var body: some View {
        Button {
            data.removeCurrent()
            tap = true
        } label: {
            ZStack {
                Circle()
                    .fill(.gray.opacity(0.25))
                    .frame(width: 64, height: 64)
                Image(systemName: "xmark")
                    .foregroundStyle(.gray.opacity(0.5))
                    .font(.system(size: 32, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove Photo")
        .task(id: tap) {
            guard tap else { return }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            tap = false
        }
        .scaleEffect(tap ? 1.2 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: tap)
        .sensoryFeedback(.success, trigger: tap)
    }
}
