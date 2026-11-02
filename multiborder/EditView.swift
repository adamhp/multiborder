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
    
    var body: some View {
        GridRow {
            Image(systemName: "square.dashed")
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                // Shows 0–64, the same scale the app used before padding became a fraction.
                let paddingMax = BorderSettings.paddingRange.upperBound
                LabeledSlider("Border Width",
                              value: Binding(
                                get: { data.settings.paddingFraction },
                                set: { newVal in
                                    withAnimation {
                                        data.settings.paddingFraction = newVal
                                    }
                                }),
                              in: BorderSettings.paddingRange, step: paddingMax / 64, displayScale: 64 / paddingMax)
                let isBlurred = data.settings.fill == .blur
                Button {
                    withAnimation {
                        data.settings.fill = isBlurred ? .color : .blur
                    }
                } label: {
                    Image(systemName: isBlurred ? "drop.halffull" : "drop")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(isBlurred ? .accent : .white)
                        .frame(width: 40, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Blurred Photo Border")
                .accessibilityAddTraits(isBlurred ? .isSelected : [])
                .sensoryFeedback(.selection, trigger: data.settings.fill)
                if isBlurred {
                    // Shows 5–100% in steps of 5.
                    LabeledSlider("Blur Strength", value: Bindable(data).settings.blurFraction,
                                  in: BorderSettings.blurRange, step: 0.005, displayScale: 1000, suffix: "%")
                    .frame(width: 96)
                    .transition(.opacity)
                } else {
                    ColorPicker("Border Color",
                        selection: Binding(
                            get: { Color(data.settings.borderColor) },
                            set: { newVal in data.settings.borderColor = newVal.resolve(in: EnvironmentValues()) }
                        ),
                        supportsOpacity: false)
                    .labelsHidden()
                    .frame(maxWidth: 48)
                    .transition(.opacity)
                }
            }
        }
        .frame(minHeight: 32)
    }
}

/// A stepped slider with its value shown above it as a whole number, `value * displayScale`,
/// followed by `suffix`.
struct LabeledSlider: View {

    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let displayScale: Double
    let suffix: String

    init(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
         displayScale: Double, suffix: String = "") {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.displayScale = displayScale
        self.suffix = suffix
    }

    private var label: Int { Int((value * displayScale).rounded()) }

    var body: some View {
        ZStack {
            Slider(value: $value, in: range, step: step) {
                Text(title)
            }
            .accessibilityValue("\(label)\(suffix)")
            .sensoryFeedback(.selection, trigger: value)
            .frame(height: 32)
            Text("\(label)\(suffix)").font(.spaceMono(16))
                .contentTransition(.numericText(value: Double(label)))
                .padding(.leading, 8.0)
                .padding(.bottom, 44)
                .fixedSize()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
        }
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
