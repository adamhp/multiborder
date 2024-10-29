//
//  SelectView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI
import PhotosUI

struct SelectView: View {
    
    @EnvironmentObject private var data: DataModel
    
    var body: some View {
        DefaultPage {
            VStack(spacing: 0) {
                Spacer()
                if data.attachments.count > 0 {
                    Text("\(data.currentIndex+1) of \(data.attachments.count)")
                        .contentTransition(.numericText(value: Double(data.currentIndex)))
                        .font(Font.custom("SpaceMono-Regular", size: 14))
                        .foregroundColor(.accent)
                        .padding(.top, 16)
                    Text("(Preview Resolution)")
                        .contentTransition(.numericText(value: Double(data.currentIndex)))
                        .font(Font.custom("SpaceMono-Regular", size: 12))
                        .foregroundColor(.stone500)
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
                        ZStack {
                            if data.helpTextShown {
                                Text("Select some photos first!")
                                    .kerning(0)
                                    .animation(.easeInOut(duration:1), value: data.helpTextShown)
                                    .font(Font.custom("SpaceMono-Regular", size: 16))
                                    .foregroundColor(.accent)
                                    .padding(.bottom, 128)
                            }
                            SelectButton().animation(.easeInOut(duration: 0.5), value: data.selection.isEmpty)
                        }
                    }
                    .frame(height: 64)
                } else {
                    ClearButton(data: data)
                        .frame(height: 64)
                }
            }
            .sensoryFeedback(.success, trigger: !data.selection.isEmpty)
            .onChange(of: data.helpTextShown, {
                if data.helpTextShown {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            data.helpTextShown = false
                        }
                    }
                }
            })
        
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
                .foregroundColor(.accent)
                .font(.system(size: 32, weight: .semibold))
        }
    }
}

struct ClearButton: View {
    
    let data: DataModel
    
    @State var tap = false
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundColor(.gray.opacity(0.25))
                .frame(width: 64, height: 64)
            Image(systemName: "xmark")
                .foregroundColor(.gray.opacity(0.5))
                .font(.system(size: 32, weight: .semibold))
        }
        .onTapGesture {
            data.removeCurrent()
            tap = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tap = false
            }
        }
        .scaleEffect(tap ? 1.2 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: tap)
        .sensoryFeedback(.success, trigger: tap)
    }
}
