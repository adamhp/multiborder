//
//  EditView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct EditView: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        let isPerSide = data.settings.isPerSide
        DefaultPage {
            VStack(spacing: 0) {
                Spacer()
                // The sliders take space from the preview, which shrinks to make room.
                // `ImageStack` keeps its place in the hierarchy either way, so its state survives the toggle.
                VStack(spacing: 0) {
                    if isPerSide {
                        EdgeSlider(.top).padding(.horizontal, EdgeSlider.thickness)
                    }
                    HStack(spacing: 0) {
                        if isPerSide {
                            EdgeSlider(.leading)
                        }
                        ImageStack()
                        if isPerSide {
                            EdgeSlider(.trailing)
                        }
                    }
                    if isPerSide {
                        EdgeSlider(.bottom).padding(.horizontal, EdgeSlider.thickness)
                    }
                }
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
            let isPerSide = data.settings.isPerSide
            Button {
                withAnimation {
                    if !isPerSide && data.settings.sides == nil {
                        // The first time, each side starts at the current width so nothing jumps.
                        data.settings.sides = BorderInsets(uniform: data.settings.paddingFraction)
                    }
                    data.settings.isPerSide.toggle()
                }
            } label: {
                Image(systemName: "square.dashed")
                    .foregroundStyle(isPerSide ? .accent : .white)
                    .frame(width: 32, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Separate Border for Each Side")
            .accessibilityAddTraits(isPerSide ? .isSelected : [])
            .sensoryFeedback(.selection, trigger: isPerSide)
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
                              in: BorderSettings.paddingRange, step: paddingMax / 64, displayScale: 64 / paddingMax,
                              showsValue: !isPerSide)
                // The sliders around the preview set the width while each side is separate.
                .disabled(isPerSide)
                .opacity(isPerSide ? 0.4 : 1)
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

/// Sets the border on `edge` while `BorderSettings.isPerSide` is on, on the same 0–64 scale as
/// the Border Width slider. Top and bottom sliders lift their value away from the photo into room kept beside
/// the track. Left and right sliders run vertically, minimum at the bottom, along 80% of the height they're given,
/// and lift their value inward over the photo, far enough to clear the thumb of the hand dragging it.
struct EdgeSlider: View {

    /// Width of a left or right slider, so the top and bottom sliders can line up with the photo.
    static let thickness = 32.0
    /// Room kept beside a top or bottom track for the lifted value.
    private static let labelRoom = 24.0
    private static let sideLift = 84.0

    @Environment(DataModel.self) private var data
    @State private var isEditing = false
    let edge: Edge

    init(_ edge: Edge) {
        self.edge = edge
    }

    private var side: WritableKeyPath<BorderInsets, Double> {
        switch edge {
        case .top: \.top
        case .leading: \.left
        case .bottom: \.bottom
        case .trailing: \.right
        }
    }

    private var title: LocalizedStringKey {
        switch edge {
        case .top: "Top Border"
        case .leading: "Left Border"
        case .bottom: "Bottom Border"
        case .trailing: "Right Border"
        }
    }

    var body: some View {
        let range = BorderSettings.paddingRange
        let step = range.upperBound / 64
        let displayScale = 64 / range.upperBound
        let value = Binding(
            get: { data.settings.insets[keyPath: side] },
            set: { newVal in
                withAnimation {
                    var sides = data.settings.insets
                    sides[keyPath: side] = newVal
                    data.settings.sides = sides
                }
            })
        Group {
            switch edge {
            case .top, .bottom:
                LabeledSlider(title, value: value, in: range, step: step, displayScale: displayScale,
                              liftsDown: edge == .bottom)
                    .padding(edge == .top ? .top : .bottom, Self.labelRoom)
            case .leading, .trailing:
                let display = Int((value.wrappedValue * displayScale).rounded())
                GeometryReader { geo in
                    let length = geo.size.height * 0.8
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let lift = edge == .leading ? Self.sideLift : -Self.sideLift
                    Slider(value: value, in: range, step: step) {
                        Text(title)
                    } onEditingChanged: { editing in
                        withAnimation(.snappy) { isEditing = editing }
                    }
                    .accessibilityValue("\(display)")
                    .sensoryFeedback(.selection, trigger: value.wrappedValue)
                    .frame(width: length)
                    .rotationEffect(.degrees(-90))
                    .position(center)
                    ThumbValue(text: "\(display)", number: display, isLifted: isEditing)
                        .position(x: center.x + (isEditing ? lift : 0),
                                  y: center.y + length / 2
                                    - ThumbValue.thumbCenter(fraction: range.fraction(of: value.wrappedValue), length: length))
                }
                .frame(width: Self.thickness)
            }
        }
        // A side value lifts over the photo, so it must draw above it.
        .zIndex(1)
        .transition(.opacity)
    }
}

/// A slider's value that rides in its thumb, small and dark on the white thumb. While the slider is being
/// dragged (`isLifted`) it grows and moves on a dark pill the size of the thumb, so the finger doesn't cover it.
/// The owner positions it, following the thumb with `thumbCenter`.
struct ThumbValue: View {

    /// Size of the system slider's thumb, along and across the track. The slider doesn't expose where
    /// its thumb is, so the value's position is worked out from this.
    static let thumbSize = CGSize(width: 38, height: 24)

    let text: String
    let number: Int
    let isLifted: Bool

    /// The thumb's center, measured from the minimum end of a track `length` long.
    static func thumbCenter(fraction: Double, length: Double) -> Double {
        thumbSize.width / 2 + min(max(fraction, 0), 1) * max(length - thumbSize.width, 0)
    }

    var body: some View {
        Text(text).font(.spaceMono(16))
            .contentTransition(.numericText(value: Double(number)))
            // Dark to sit on the white thumb; light once lifted.
            .foregroundStyle(isLifted ? .white : .stone800)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
            // Keeps the lifted value readable over the photo or a white border.
            .background(isLifted ? Color.stone800 : .clear, in: .capsule)
            .scaleEffect(isLifted ? 1 : 0.8)
            // Touches on the thumb go to the slider.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension ClosedRange<Double> {
    /// Where `value` sits in the range, 0 at the lower bound and 1 at the upper.
    func fraction(of value: Double) -> Double {
        upperBound > lowerBound ? (value - lowerBound) / (upperBound - lowerBound) : 0
    }
}

/// A stepped slider whose value, `value * displayScale` as a whole number followed by `suffix`, rides in the
/// thumb and lifts above it (or below, with `liftsDown`) while dragging. `showsValue` hides the number.
struct LabeledSlider: View {

    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let displayScale: Double
    let suffix: String
    let showsValue: Bool
    let liftsDown: Bool
    @State private var isEditing = false

    init(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
         displayScale: Double, suffix: String = "", showsValue: Bool = true, liftsDown: Bool = false) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.displayScale = displayScale
        self.suffix = suffix
        self.showsValue = showsValue
        self.liftsDown = liftsDown
    }

    private var label: Int { Int((value * displayScale).rounded()) }

    var body: some View {
        Slider(value: $value, in: range, step: step) {
            Text(title)
        } onEditingChanged: { editing in
            withAnimation(.snappy) { isEditing = editing }
        }
        .accessibilityValue("\(label)\(suffix)")
        .sensoryFeedback(.selection, trigger: value)
        .frame(height: 32)
        .overlay {
            if showsValue {
                GeometryReader { geo in
                    // Lifts clear of the 32pt track into the room beside it.
                    let lift = liftsDown ? 28.0 : -28.0
                    ThumbValue(text: "\(label)\(suffix)", number: label, isLifted: isEditing)
                        .position(x: ThumbValue.thumbCenter(fraction: range.fraction(of: value), length: geo.size.width),
                                  y: geo.size.height / 2 + (isEditing ? lift : 0))
                }
                .transition(.opacity)
            }
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
