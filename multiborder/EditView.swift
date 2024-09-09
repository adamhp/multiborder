//
//  EditView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct EditView: View {
    
    @EnvironmentObject private var data: DataModel

    var body: some View {
        DefaultPage {
            VStack(spacing: 0) {
                Spacer()
                ImageStack()
                Spacer()
                Grid(horizontalSpacing: 16, verticalSpacing: 24) {
                    DesiredPaddingSlider()
                    DesiredAspectRatioChooser()
                }
                .padding(.horizontal, 32)
                .frame(height: 128)
            }
        }
    }
}

struct DesiredPaddingSlider: View {
    
    @EnvironmentObject private var data: DataModel
    @State private var desiredPaddingValue: Double = 0
    @State private var borderColorValue = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0)
    @State private var isEditing: Bool = false
    
    var body: some View {
        GridRow {
            Image(systemName: "square.dashed").frame(width: 32, height: 32)
            HStack(spacing: 0) {
                ZStack {
                    Slider(
                        value: Binding(get: { self.desiredPaddingValue }, set: { newVal in
                            withAnimation {
                                self.desiredPaddingValue = newVal
                            }
                            data.setDesiredPadding(value: CGFloat(self.desiredPaddingValue))
                        }),
                        in: 0...64,
                        step: 1
                    ) {
                        Text("Padding")
                    }
                    .frame(height: 32)
                    Text("\(Int(desiredPaddingValue))").font(Font.custom("SpaceMono-Regular", size: 16))
                        .contentTransition(.numericText(value: desiredPaddingValue))
                        .padding(.leading, 8.0)
                        .padding(.bottom, 44)
                        .fixedSize()
                        .frame(width: 32, height: 32)
                }
                ColorPicker("", selection: $borderColorValue, supportsOpacity: false).labelsHidden().onChange(of: borderColorValue, {
                    data.setDesiredBorderColor(value: borderColorValue)
                })
                .frame(maxWidth: 48)
            }
        }
        .frame(height:32)
    }
}

struct DesiredAspectRatioChooser: View {
    
    @EnvironmentObject private var data: DataModel
    @State private var desiredAspectRatioValue: Double = 0
    
    var body: some View {
        GridRow {
            Image(systemName: "aspectratio").frame(width: 32, height: 32)
            HStack(spacing: 4) {
                
                /// Original
                Button {
                    data.setDesiredAspectRatio(value: -1)
                } label: {
                    Image(systemName: "photo.artframe")
                }
                .buttonStyle(AspectRatioButton(active: data.desiredAspectRatio == -1))
                
                Button {
                    data.setDesiredAspectRatio(value: 2/3)
                } label: {
                    Text("2:3").font(Font.custom("SpaceMono-Regular", size: 16))
                }
                .buttonStyle(AspectRatioButton(active: data.desiredAspectRatio == 2/3))
                
                Button {
                    data.setDesiredAspectRatio(value: 3/4)
                    
                } label: {
                    Text("3:4").font(Font.custom("SpaceMono-Regular", size: 16))
                }
                .buttonStyle(AspectRatioButton(active: data.desiredAspectRatio == 3/4))
                
                Button {
                    data.setDesiredAspectRatio(value: 4/5)
                } label: {
                    Text("4:5").font(Font.custom("SpaceMono-Regular", size: 16))
                }
                .buttonStyle(AspectRatioButton(active: data.desiredAspectRatio == 4/5))
                
                Button {
                    data.setDesiredAspectRatio(value: 1.0)
                } label: {
                    Text("1:1").font(Font.custom("SpaceMono-Regular", size: 16))
                }
                .buttonStyle(AspectRatioButton(active: data.desiredAspectRatio == 1.0))
            }
            .frame(height: 32)
        }
        .frame(height:32)
    }
}

struct AspectRatioButton: ButtonStyle {
    var active = false
    
    init(active: Bool = false) {
        self.active = active
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(active ? .accent : .white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(active ? .stone800 : .stone600)
                    .frame(width: 48, height: 40))
            .frame(width: 48, height: 40)
            .sensoryFeedback(.success, trigger: active)
    }
}
