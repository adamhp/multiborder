//
//  CardStack.swift
//  multiborder
//
//  Created by Adam Pearce on 9/4/24.
//
import SwiftUI

public struct CardStack<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {

    /// How far the in-flight drag has moved the stack, in cards (positive moves towards later cards).
    /// Reset to zero with the snap spring when the drag ends or is cancelled.
    @GestureState(resetTransaction: Transaction(animation: .interpolatingSpring(stiffness: 300, damping: 40)))
    private var dragOffset: Double = 0

    private var data: Data

    @ViewBuilder private let content: (Data.Element) -> Content
    /// The resting index of the topmost card; the single source of truth for the stack's position.
    @Binding private var currentIndex: Int

    /// Creates a stack with the given content
    /// - Parameters:
    ///   - data: The identifiable data for computing the list.
    ///   - currentIndex: The index of the topmost card in the stack. Dragging or using the
    ///     VoiceOver adjustable action updates it, and the stack follows changes made to it.
    ///   - content: A view builder that creates the view for a single card
    public init(_ data: Data, currentIndex: Binding<Int>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
        _currentIndex = currentIndex
    }

    public var body: some View {
        let position = self.position
        ZStack {
            // Only cards near the current position can be seen, so the rest aren't built.
            ForEach(visibleCards(around: position), id: \.element.id) { card in
                content(card.element)
                    .zIndex(zIndex(for: card.index, position: position))
                    .offset(x: xOffset(for: card.index, position: position), y: 0)
                    .scaleEffect(scale(for: card.index, position: position), anchor: .center)
                    .rotationEffect(.degrees(rotationDegrees(for: card.index, position: position)))
            }
        }
        // Keep the binding valid when cards are removed, or when the stack appears with a stale index.
        .onChange(of: data.count, initial: true) {
            let clamped = restingIndex
            if currentIndex != clamped {
                currentIndex = clamped
            }
        }
        .highPriorityGesture(dragGesture)
        // VoiceOver can't drag the stack, so it moves between cards by swiping up or down.
        .accessibilityElement(children: .ignore)
        .accessibilityAdjustableAction { direction in
            let step: Int
            switch direction {
            case .increment: step = 1
            case .decrement: step = -1
            @unknown default: return
            }
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 40)) {
                currentIndex = CardStackLayout.clampedIndex(restingIndex + step, count: data.count)
            }
        }
    }

    /// The bound index clamped to the cards that exist.
    private var restingIndex: Int {
        CardStackLayout.clampedIndex(currentIndex, count: data.count)
    }

    /// The fractional index of the topmost card, including any in-flight drag.
    private var position: Double {
        Double(restingIndex) + dragOffset
    }

    private func visibleCards(around position: Double) -> [(index: Int, element: Data.Element)] {
        CardStackLayout.visibleRange(around: position, count: data.count).map { index in
            (index, data[data.index(data.startIndex, offsetBy: index)])
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, transaction in
                transaction.animation = .interactiveSpring()
                state = CardStackLayout.dragOffset(forTranslation: value.translation.width)
            }
            .onEnded { value in
                let target = CardStackLayout.snapTarget(
                    restingIndex: restingIndex,
                    translation: value.translation.width,
                    predictedEndTranslation: value.predictedEndTranslation.width,
                    count: data.count
                )
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 40)) {
                    currentIndex = target
                }
            }
    }

    private func zIndex(for index: Int, position: Double) -> Double {
        if (Double(index) + 0.5) < position {
            return -Double(data.count - index)
        } else {
            return Double(data.count - index)
        }
    }

    private func xOffset(for index: Int, position: Double) -> CGFloat {
        let topCardProgress = currentPosition(for: index, position: position)
        let padding = 35.0
        let x = ((CGFloat(index) - position) * padding)
        if topCardProgress > 0 && topCardProgress < 0.99 && index < (data.count - 1) {
            return x * swingOutMultiplier(topCardProgress)
        }
        return x
    }

    private func scale(for index: Int, position: Double) -> CGFloat {
        return 1.0 - (0.1 * abs(currentPosition(for: index, position: position)))
    }

    private func rotationDegrees(for index: Int, position: Double) -> Double {
        return -currentPosition(for: index, position: position) * 2
    }

    private func currentPosition(for index: Int, position: Double) -> Double {
        position - Double(index)
    }

    private func swingOutMultiplier(_ progress: Double) -> Double {
        return sin(Double.pi * progress) * 5
    }
}

/// The index arithmetic behind `CardStack`, kept separate so it can be unit tested.
nonisolated enum CardStackLayout {

    /// Points of horizontal drag that move the stack by one card.
    static let pointsPerCard = 300.0
    /// A drag whose predicted end is further than this, in points, moves exactly one card.
    static let flingThreshold = 200.0
    /// Cards rendered on each side of the current position. Cards more than a few away are
    /// off screen; the extra margin keeps cards from popping in or out during a drag or the
    /// spring animation after one.
    static let windowRadius = 7

    /// `index` clamped to `0..<count`, or 0 when there are no cards.
    static func clampedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    /// The drag offset in cards for a horizontal translation; dragging left moves to later cards.
    static func dragOffset(forTranslation translation: Double) -> Double {
        -translation / pointsPerCard
    }

    /// The indices to render for a stack whose topmost card is at the fractional `position`.
    static func visibleRange(around position: Double, count: Int) -> Range<Int> {
        guard count > 0 else { return 0..<0 }
        // Clamp first so a drag past either end still shows the end cards and can't overflow `Int`.
        let clamped = position.isNaN ? 0 : min(max(position, 0), Double(count - 1))
        let lower = max(Int(clamped.rounded(.down)) - windowRadius, 0)
        let upper = min(Int(clamped.rounded(.up)) + windowRadius, count - 1)
        return lower..<(upper + 1)
    }

    /// The index a drag settles on: one card forwards or back for a fling, otherwise the
    /// card nearest to where the drag was released. Always a valid index (0 when empty).
    static func snapTarget(restingIndex: Int, translation: Double, predictedEndTranslation: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let target: Int
        if abs(predictedEndTranslation) > flingThreshold {
            target = predictedEndTranslation > 0 ? restingIndex - 1 : restingIndex + 1
        } else {
            let released = Double(restingIndex) + dragOffset(forTranslation: translation)
            let clamped = released.isNaN ? Double(restingIndex) : min(max(released, 0), Double(count - 1))
            target = Int(clamped.rounded())
        }
        return clampedIndex(target, count: count)
    }
}

#Preview {
    struct DemoItem: Identifiable {
        let name: String
        let color: Color
        var id: String { name }
    }

    @Previewable @State var currentIndex = 0

    let colors = [
        DemoItem(name: "Red", color: .red),
        DemoItem(name: "Orange", color: .orange),
        DemoItem(name: "Yellow", color: .yellow),
        DemoItem(name: "Green", color: .green),
        DemoItem(name: "Blue", color: .blue),
        DemoItem(name: "Purple", color: .purple),
    ]

    return VStack {
        CardStack(colors, currentIndex: $currentIndex) { namedColor in
            Rectangle()
                .fill(namedColor.color)
                .overlay(
                    Text(namedColor.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )
                .frame(height: 400)
                .padding(50)
        }
        Text("Current card is \(currentIndex)")
    }
}
