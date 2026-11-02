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
                .padding(.horizontal, 20)
                .frame(minHeight: 128)
                // Six ratio buttons must fit one row; beyond this size they would truncate.
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
                    Text("\(paddingLabel)").font(.spaceMono(16))
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
        let settings = data.settings
        GridRow {
            Button {
                data.settings.isLandscape.toggle()
            } label: {
                Image(systemName: settings.isLandscape ? "rectangle.landscape.rotate" : "rectangle.portrait.rotate")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // Original and square look the same either way round.
            .disabled(!settings.aspectRatio.hasOrientation)
            .opacity(settings.aspectRatio.hasOrientation ? 1 : 0.4)
            .accessibilityLabel("Orientation")
            .accessibilityValue(settings.isLandscape ? "Landscape" : "Portrait")
            .sensoryFeedback(.selection, trigger: settings.isLandscape)
            HStack(spacing: 4) {
                ForEach(AspectRatio.allCases) { ratio in
                    let title = ratio.title(landscape: settings.isLandscape)
                    Button {
                        data.settings.aspectRatio = ratio
                    } label: {
                        if ratio == .original {
                            Image(systemName: "photo.artframe")
                        } else {
                            Text(title).font(.spaceMono(16))
                        }
                    }
                    .buttonStyle(AspectRatioButton(active: settings.aspectRatio == ratio))
                    .accessibilityLabel(ratio == .original ? "Original Aspect Ratio" : "Aspect Ratio \(title)")
                    .accessibilityAddTraits(settings.aspectRatio == ratio ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: settings.aspectRatio)
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 4)
            // The buttons share the row equally.
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(active ? .stone800 : .stone600, in: .rect(cornerRadius: 12))
    }
}
