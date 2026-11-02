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
                // Drag-to-select works with this mode and the top bar showing; it didn't with
                // .continuousAndOrdered or .ordered and the top bar hidden (iPhone 16 Pro, iOS 26).
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

/// The picked photos as a card stack, with the button that removes them.
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
            ClearButton(data: data)
                .frame(height: 64)
        }
    }
}

/// Tap to remove the current photo; hold until the ring fills to remove them all.
struct ClearButton: View {

    /// A press shorter than this is a tap; a longer one starts the hold.
    static let tapDuration: Duration = .milliseconds(250)
    /// How long the ring takes to fill once the hold starts.
    static let holdDuration: Duration = .seconds(1.5)
    /// Haptic taps while the ring fills, each a little stronger than the last.
    static let holdTicks = 20

    let data: DataModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tap = false
    /// True while the finger is down; resets on its own if the system cancels the touch,
    /// so an interrupted hold can't go on to remove everything.
    @GestureState private var isPressed = false
    /// When the current press began, to tell a tap from an abandoned hold.
    @State private var pressStart: ContinuousClock.Instant?
    /// How full the ring is, 0...1.
    @State private var holdProgress = 0.0
    /// Haptic taps played so far in the current hold.
    @State private var holdTick = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(.gray.opacity(0.25))
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "xmark")
                .foregroundStyle(holdProgress > 0 ? Color.accent : Color.gray.opacity(0.5))
                .font(.system(size: 32, weight: .semibold))
        }
        .frame(width: 64, height: 64)
        .contentShape(.circle)
        .scaleEffect(tap ? 1.2 : 1 + (reduceMotion ? 0 : 0.3 * holdProgress))
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: tap)
        .gesture(press)
        .task(id: isPressed) {
            guard isPressed else {
                pressStart = nil
                holdTick = 0
                withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
                return
            }
            do {
                try await Task.sleep(for: Self.tapDuration)
                withAnimation(.linear(duration: Self.holdDuration / .seconds(1))) { holdProgress = 1 }
                for tick in 1...Self.holdTicks {
                    try await Task.sleep(for: Self.holdDuration / Self.holdTicks)
                    holdTick = tick
                }
            } catch {
                return
            }
            data.clearSelection()
        }
        .task(id: tap) {
            guard tap else { return }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            tap = false
        }
        .sensoryFeedback(.success, trigger: tap)
        .sensoryFeedback(trigger: holdTick) { _, tick in
            guard tick > 0 else { return nil }
            let fraction = Double(tick) / Double(Self.holdTicks)
            // Firm from the first tap, so the hold is unmistakable, then heavier as the ring fills.
            let weight: SensoryFeedback.Weight = fraction < 1.0 / 3 ? .light : fraction < 2.0 / 3 ? .medium : .heavy
            return .impact(weight: weight, intensity: 0.5 + 0.5 * fraction)
        }
        .accessibilityElement()
        .accessibilityLabel("Remove Photo")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Hold to remove all photos")
        .accessibilityAction { removeCurrent() }
        .accessibilityAction(named: "Remove All Photos") { data.clearSelection() }
    }

    /// Tracks the finger directly, so a quick release is a tap and an
    /// abandoned hold does nothing instead of falling back to a tap.
    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, pressed, _ in pressed = true }
            .onChanged { _ in
                if pressStart == nil {
                    pressStart = .now
                }
            }
            .onEnded { _ in
                guard let start = pressStart else { return }
                pressStart = nil
                if ContinuousClock.now - start < Self.tapDuration {
                    removeCurrent()
                }
            }
    }

    private func removeCurrent() {
        data.removeCurrent()
        tap = true
    }
}
