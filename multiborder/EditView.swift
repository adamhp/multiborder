//
//  EditView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct EditView: View {

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
                .frame(minHeight: 128)
                // Five ratio buttons must fit one row; beyond this size they would truncate.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
    }
}

struct DesiredPaddingSlider: View {
    
    @Environment(DataModel.self) private var data
    
    /// The slider shows 0–64, the same scale the app used before padding became a fraction.
    private var paddingLabel: Int {
        Int((data.settings.paddingFraction / BorderSettings.paddingRange.upperBound * 64).rounded())
    }
    
    var body: some View {
        GridRow {
            Image(systemName: "square.dashed")
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                ZStack {
                    Slider(
                        value: Binding(
                            get: { data.settings.paddingFraction },
                            set: { newVal in
                                withAnimation {
                                    data.settings.paddingFraction = newVal
                                }
                            }),
                        in: BorderSettings.paddingRange,
                        step: BorderSettings.paddingRange.upperBound / 64
                    ) {
                        Text("Border Width")
                    }
                    .accessibilityValue("\(paddingLabel)")
                    .sensoryFeedback(.selection, trigger: data.settings.paddingFraction)
                    .frame(height: 32)
                    Text("\(paddingLabel)").font(Font.custom("SpaceMono-Regular", size: 16))
                        .contentTransition(.numericText(value: Double(paddingLabel)))
                        .padding(.leading, 8.0)
                        .padding(.bottom, 44)
                        .fixedSize()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                }
                ColorPicker("Border Color",
                    selection: Binding(
                        get: { Color(data.settings.borderColor) },
                        set: { newVal in data.settings.borderColor = newVal.resolve(in: EnvironmentValues()) }
                    ),
                    supportsOpacity: false)
                .labelsHidden()
                .frame(maxWidth: 48)
            }
        }
        .frame(minHeight: 32)
    }
}

struct DesiredAspectRatioChooser: View {
    
    @Environment(DataModel.self) private var data
    
    var body: some View {
        GridRow {
            Image(systemName: "aspectratio")
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            HStack(spacing: 4) {
                ForEach(AspectRatio.allCases) { ratio in
                    Button {
                        data.settings.aspectRatio = ratio
                    } label: {
                        if ratio == .original {
                            Image(systemName: "photo.artframe")
                        } else {
                            Text(ratio.title).font(Font.custom("SpaceMono-Regular", size: 16))
                        }
                    }
                    .buttonStyle(AspectRatioButton(active: data.settings.aspectRatio == ratio))
                    .accessibilityLabel(ratio == .original ? "Original Aspect Ratio" : "Aspect Ratio \(ratio.title)")
                    .accessibilityAddTraits(data.settings.aspectRatio == ratio ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: data.settings.aspectRatio)
        }
        .frame(minHeight: 32)
    }
}

struct AspectRatioButton: ButtonStyle {
    
    var active = false
    
    init(active: Bool = false) {
        self.active = active
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? .accent : .white)
            .padding(.horizontal, 6)
            .frame(minWidth: 48, minHeight: 40)
            .background(active ? .stone800 : .stone600, in: .rect(cornerRadius: 12))
    }
}
