//
//  EditView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct EditView: View {

    /// Every row of controls below the preview gets this much height, so the rows are evenly spaced.
    static let controlRowHeight = 44.0

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
                if data.settings.showsCaption {
                    CaptionFieldsRow()
                        .transition(.opacity)
                }
                Grid(horizontalSpacing: 16, verticalSpacing: 0) {
                    EditToggles()
                    if data.settings.roundsCorners {
                        // Shows 1–64, on the border width's scale.
                        let cornerMax = BorderSettings.cornerRange.upperBound
                        EditOptionSlider(title: "Corner Radius", systemImage: "app", keyPath: \.cornerFraction,
                                         range: BorderSettings.cornerRange, step: cornerMax / 64,
                                         displayScale: 64 / cornerMax)
                    }
                    if data.settings.hasShadow {
                        // Shows 5–100% in steps of 5.
                        let shadowMax = BorderSettings.shadowRange.upperBound
                        EditOptionSlider(title: "Shadow", systemImage: "shadow", keyPath: \.shadowFraction,
                                         range: BorderSettings.shadowRange, step: shadowMax / 20,
                                         displayScale: 100 / shadowMax, suffix: "%")
                    }
                    DesiredPaddingSlider()
                    DesiredAspectRatioChooser()
                }
                .padding(.horizontal, 20)
                // Six ratio buttons must fit one row; beyond this size they would truncate.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
    }
}

/// Switches for the border's options, in a row above the sliders: separate sides, rounded corners,
/// the shadow, the caption and the blurred fill. Corners and shadow add a slider row while on.
struct EditToggles: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        let settings = data.settings
        GridRow {
            HStack(spacing: 0) {
                EditToggle("Separate Border for Each Side", systemImage: "square.dashed", isOn: settings.isPerSide) {
                    if !settings.isPerSide && settings.sides == nil {
                        // The first time, each side starts at the current width so nothing jumps.
                        data.settings.sides = BorderInsets(uniform: settings.paddingFraction)
                    }
                    data.settings.isPerSide.toggle()
                }
                EditToggle("Rounded Corners", systemImage: "app", isOn: settings.roundsCorners) {
                    data.settings.roundsCorners.toggle()
                }
                EditToggle("Shadow", systemImage: "shadow", isOn: settings.hasShadow) {
                    data.settings.hasShadow.toggle()
                }
                EditToggle("Camera Settings Caption", systemImage: "text.below.photo", isOn: settings.showsCaption) {
                    data.settings.showsCaption.toggle()
                }
                EditToggle("Blurred Photo Border", systemImage: settings.fill == .blur ? "drop.halffull" : "drop",
                           isOn: settings.fill == .blur) {
                    data.settings.fill = settings.fill == .blur ? .color : .blur
                }
            }
            .gridCellColumns(2)
        }
        .frame(height: EditView.controlRowHeight)
    }
}

/// One of `EditToggles`' switches: an icon, accent while on, sharing the row equally with the others.
private struct EditToggle: View {

    let title: LocalizedStringKey
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String, isOn: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isOn = isOn
        self.action = action
    }

    var body: some View {
        Button {
            withAnimation { action() }
        } label: {
            Image(systemName: systemImage)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isOn ? .accent : .white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// The strength of an option switched on in `EditToggles`, with the option's icon at the start of the row.
struct EditOptionSlider: View {

    @Environment(DataModel.self) private var data
    let title: LocalizedStringKey
    let systemImage: String
    let keyPath: WritableKeyPath<BorderSettings, Double>
    let range: ClosedRange<Double>
    let step: Double
    let displayScale: Double
    var suffix = ""

    var body: some View {
        GridRow {
            Image(systemName: systemImage)
                .foregroundStyle(.stone400)
                .frame(width: 32, height: 40)
                .accessibilityHidden(true)
            LabeledSlider(title,
                          value: Binding(
                            get: { data.settings[keyPath: keyPath] },
                            set: { newVal in
                                withAnimation {
                                    data.settings[keyPath: keyPath] = newVal
                                }
                            }),
                          in: range, step: step, displayScale: displayScale, suffix: suffix)
        }
        .frame(height: EditView.controlRowHeight)
        .transition(.opacity)
    }
}

struct DesiredPaddingSlider: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        GridRow {
            let isPerSide = data.settings.isPerSide
            Image(systemName: "rectangle.inset.filled")
                .foregroundStyle(.stone400)
                .frame(width: 32, height: 40)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
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
                if data.settings.fill == .blur {
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
        .frame(height: EditView.controlRowHeight)
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

/// The caption's details as pills in two rows, matching the rows above and below the photo, shown above
/// the border controls while the caption is on. Tapping a pill turns its detail on or off (the handle's opens
/// its editor); dragging moves it along its row or into the other one. A button at the start of each row
/// cycles how that row is arranged across the photo.
struct CaptionFieldsRow: View {

    private static let pillSize = CGSize(width: 48, height: 28)
    private static let spacing = 6.0
    private static let rowHeight = EditView.controlRowHeight
    private static let coordinateSpace = "captionFields"

    @Environment(DataModel.self) private var data
    /// Width of the area the pills are centered in.
    @State private var width = 0.0
    @State private var dragged: CaptionField?
    /// Where the dragged pill's center is, following the finger.
    @State private var dragCenter = CGPoint.zero
    /// The dragged pill's center when the drag began.
    @State private var dragStart = CGPoint.zero
    /// The field whose options popover is open: the handle's or the camera's.
    @State private var editing: CaptionField?
    @State private var isEditingStyle = false

    var body: some View {
        let settings = data.settings
        // Laid out like the grid below: the same margin, column width and spacing, so the buttons
        // at the start of every row line up.
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                alignmentButton(.above, settings: settings)
                    .frame(height: Self.rowHeight)
                alignmentButton(.below, settings: settings)
                    .frame(height: Self.rowHeight)
            }
            // One flat list of pills, placed by position rather than by two stacks, so a pill keeps its
            // identity (and its drag) as it moves from one row to the other.
            ZStack {
                ForEach(CaptionField.allCases, id: \.self) { field in
                    pill(field, settings: settings)
                        .position(dragged == field ? dragCenter : center(of: field, in: settings))
                        .zIndex(dragged == field ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .coordinateSpace(.named(Self.coordinateSpace))
            Button {
                isEditingStyle = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 32, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Caption Style")
            .popover(isPresented: $isEditingStyle) {
                CaptionStyleEditor()
                    .presentationCompactAdaptation(.popover)
            }
        }
        .frame(height: Self.rowHeight * 2)
        .padding(.horizontal, 20)
        .sensoryFeedback(.selection, trigger: settings.captionFields)
        .sensoryFeedback(.selection, trigger: [settings.captionAbove, settings.captionBelow])
        .sensoryFeedback(.impact(weight: .light), trigger: dragged) { _, new in new != nil }
    }

    private func alignmentButton(_ row: CaptionRow, settings: BorderSettings) -> some View {
        let alignment = settings.captionAlignment(in: row)
        return Button {
            withAnimation(.snappy) {
                if row == .above {
                    data.settings.captionAlignmentAbove = alignment.next
                } else {
                    data.settings.captionAlignmentBelow = alignment.next
                }
            }
        } label: {
            Image(systemName: alignment.symbolName)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row == .above ? "Top Row Arrangement" : "Bottom Row Arrangement")
        .accessibilityValue(alignment.title)
        .sensoryFeedback(.selection, trigger: alignment)
    }

    /// Distance between neighboring pills' centers, narrowed if a row holds more pills than fit.
    private func slot(in settings: BorderSettings) -> Double {
        let mostPills = Double(max(settings.captionAbove.count, settings.captionBelow.count, 1))
        return min(Self.pillSize.width + Self.spacing, width / mostPills)
    }

    private func pill(_ field: CaptionField, settings: BorderSettings) -> some View {
        let isOn = settings.captionFields.contains(field) && (field != .handle || PhotoCaption.handleItem(settings) != nil)
        let isDragged = dragged == field
        let row = row(of: field, in: settings)
        return PillLabel(field: field, handleStyle: settings.handleStyle)
            .foregroundStyle(isOn ? .accent : .white.opacity(0.5))
            .frame(width: slot(in: settings) - Self.spacing, height: Self.pillSize.height)
            // A solid pill the color of the page gives each detail a handle, and covers its neighbors while dragged.
            .background(.stone800, in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(isDragged ? 0.4 : 0.15), lineWidth: 1) }
            .contentShape(.capsule)
            .shadow(color: .black.opacity(isDragged ? 0.4 : 0), radius: 6, y: 2)
            .scaleEffect(isDragged ? 1.15 : 1)
            .onTapGesture {
                tap(field)
            }
            .gesture(drag(field))
            .popover(isPresented: Binding(get: { editing == field }, set: { if !$0 { editing = nil } })) {
                Group {
                    if field == .handle { HandleEditor() } else { FieldEditor(field: field) }
                }
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityElement()
            .accessibilityLabel(field == .handle && !settings.handle.isEmpty ? "Handle, \(settings.handle)" : field.title)
            .accessibilityValue(row == .above ? "Above photo" : "Below photo")
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction {
                tap(field)
            }
            .accessibilityActions {
                let order = settings.captionOrder(in: row)
                if order.first != field {
                    Button("Move Left") { move(field, to: row, at: (order.firstIndex(of: field) ?? 0) - 1) }
                }
                if order.last != field {
                    Button("Move Right") { move(field, to: row, at: (order.firstIndex(of: field) ?? 0) + 1) }
                }
                Button(row == .above ? "Move Below Photo" : "Move Above Photo") {
                    move(field, to: row == .above ? .below : .above, at: .max)
                }
            }
    }

    private func row(of field: CaptionField, in settings: BorderSettings) -> CaptionRow {
        settings.captionAbove.contains(field) ? .above : .below
    }

    private func rowCenterY(_ row: CaptionRow) -> Double {
        row == .above ? Self.rowHeight / 2 : Self.rowHeight * 1.5
    }

    /// Where `field`'s pill sits: its row, centered as a group like the photo's caption rows.
    private func center(of field: CaptionField, in settings: BorderSettings) -> CGPoint {
        let row = row(of: field, in: settings)
        let order = settings.captionOrder(in: row)
        let index = Double(order.firstIndex(of: field) ?? 0)
        return CGPoint(x: width / 2 + (index - Double(order.count - 1) / 2) * slot(in: settings), y: rowCenterY(row))
    }

    /// Every pill opens its options.
    private func tap(_ field: CaptionField) {
        editing = field
    }

    private func move(_ field: CaptionField, to row: CaptionRow, at index: Int) {
        withAnimation(.snappy) {
            data.settings.moveCaptionField(field, to: row, at: index)
        }
    }

    private func drag(_ field: CaptionField) -> some Gesture {
        // Measured in the row's space: the pill itself moves under the finger, so its own space would
        // shift with every swap and make the pills fight.
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                let settings = data.settings
                if dragged == nil {
                    dragStart = center(of: field, in: settings)
                    dragCenter = dragStart
                    withAnimation(.snappy) { dragged = field }
                }
                dragCenter = CGPoint(x: dragStart.x + value.translation.width, y: dragStart.y + value.translation.height)

                // The row the finger is over, and the place in it the pill's center is closest to.
                let row: CaptionRow = dragCenter.y < Self.rowHeight ? .above : .below
                let count = settings.captionOrder(in: row).filter { $0 != field }.count + 1
                let place = ((dragCenter.x - width / 2) / slot(in: settings) + Double(count - 1) / 2).rounded()
                let index = min(max(Int(place), 0), count - 1)
                if row != self.row(of: field, in: settings) || settings.captionOrder(in: row).firstIndex(of: field) != index {
                    move(field, to: row, at: index)
                }
            }
            .onEnded { _ in
                withAnimation(.snappy) { dragged = nil }
            }
    }
}

/// A caption pill's face: the detail's icon, or a short label where there's no fitting symbol.
private struct PillLabel: View {

    let field: CaptionField
    let handleStyle: HandleStyle

    var body: some View {
        switch field {
        case .handle:
            if let icon = handleStyle.controlIcon {
                CaptionIconView(icon: icon).frame(width: 17, height: 17)
            } else {
                Text("@").font(.spaceMono(16))
            }
        case .iso:
            Text("ISO").font(.spaceMono(14))
        // Printed without an icon, but the pills still need one.
        case .title:
            CaptionIconView(icon: .symbol("text.quote")).frame(width: 18, height: 18)
        case .filename:
            CaptionIconView(icon: .symbol("doc")).frame(width: 18, height: 18)
        default:
            if let icon = field.icon {
                CaptionIconView(icon: icon).frame(width: 18, height: 18)
            }
        }
    }
}

/// Turns one caption detail on or off, for the options popovers.
private struct ShowFieldToggle: View {

    let field: CaptionField
    @Environment(DataModel.self) private var data

    var body: some View {
        Toggle("Show", isOn: Binding(
            get: { data.settings.captionFields.contains(field) },
            set: { isOn in
                if isOn { data.settings.captionFields.insert(field) } else { data.settings.captionFields.remove(field) }
            }))
            .font(.spaceMono(15))
    }
}

/// A caption detail's options: whether it's shown, whether its icon is printed (for details that have one),
/// and for the camera, which parts of its name.
private struct FieldEditor: View {

    let field: CaptionField
    @Environment(DataModel.self) private var data

    var body: some View {
        @Bindable var data = data
        VStack(alignment: .leading, spacing: 14) {
            if field == .camera {
                Toggle("Make", isOn: $data.settings.cameraShowsMake)
                Toggle("Model", isOn: $data.settings.cameraShowsModel)
            }
            if field.icon != nil {
                Toggle("Icon", isOn: Binding(
                    get: { !data.settings.captionHiddenIcons.contains(field) },
                    set: { shows in
                        if shows {
                            data.settings.captionHiddenIcons.remove(field)
                        } else {
                            data.settings.captionHiddenIcons.insert(field)
                        }
                    }))
                    // Overruled while every icon is turned off in the caption's style.
                    .disabled(!data.settings.showsCaptionIcons)
            }
            if field == .camera || field.icon != nil {
                Divider()
            }
            ShowFieldToggle(field: field)
        }
        .font(.spaceMono(15))
        .padding(16)
        .frame(width: 220)
    }
}

/// The caption's look as a whole: its font, and whether icons are printed at all.
private struct CaptionStyleEditor: View {

    @Environment(DataModel.self) private var data

    var body: some View {
        @Bindable var data = data
        VStack(alignment: .leading, spacing: 14) {
            ForEach(CaptionFont.allCases, id: \.self) { font in
                Button {
                    data.settings.captionFont = font
                } label: {
                    HStack {
                        // Each name in its own font, as a preview.
                        Text(font.title)
                            .font(.custom(font.postScriptName, fixedSize: 16))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        if data.settings.captionFont == font {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(data.settings.captionFont == font ? .isSelected : [])
            }
            Divider()
            Toggle("Icons", isOn: $data.settings.showsCaptionIcons)
                .font(.spaceMono(15))
        }
        .padding(16)
        .frame(width: 260)
        .sensoryFeedback(.selection, trigger: data.settings.captionFont)
    }
}

/// Edits the handle printed by the caption: its text, its icon, and whether it's shown.
private struct HandleEditor: View {

    @Environment(DataModel.self) private var data
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var data = data
        VStack(alignment: .leading, spacing: 14) {
            TextField("yourname", text: $data.settings.handle)
                .font(.spaceMono(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.twitter)
                .submitLabel(.done)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(.white.opacity(0.1), in: .rect(cornerRadius: 10))
                .accessibilityLabel("Handle")
            HStack(spacing: 6) {
                ForEach(HandleStyle.allCases, id: \.self) { style in
                    let isSelected = data.settings.handleStyle == style
                    Button {
                        data.settings.handleStyle = style
                    } label: {
                        Group {
                            if let icon = style.controlIcon {
                                CaptionIconView(icon: icon).frame(width: 18, height: 18)
                            } else {
                                Text("@").font(.spaceMono(17))
                            }
                        }
                        .foregroundStyle(isSelected ? .accent : .white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isSelected ? .white.opacity(0.15) : .clear, in: .rect(cornerRadius: 8))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            ShowFieldToggle(field: .handle)
        }
        .padding(16)
        .frame(width: 260)
        .sensoryFeedback(.selection, trigger: data.settings.handleStyle)
        .onAppear { isFocused = data.settings.handle.isEmpty }
        // Typing a handle means wanting it shown.
        .onChange(of: data.settings.handle.isEmpty) { _, isEmpty in
            if !isEmpty { data.settings.captionFields.insert(.handle) }
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
        .frame(height: EditView.controlRowHeight)
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
