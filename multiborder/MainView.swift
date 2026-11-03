//
//  MainView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI
import TipKit

struct MainView: View {

    @State private var data = DataModel()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $data.selectedTab) {
                SelectView()
                    .tag(TabbedItems.select)
                // Left out until photos are picked, so no swipe or tap can reach them.
                if !data.attachments.isEmpty {
                    EditView { ImageStack() }
                        .tag(TabbedItems.edit)
                    ExportView()
                        .tag(TabbedItems.export)
                }
                SettingsView()
                    .tag(TabbedItems.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // No swiping between pages until photos are picked. The picker shows until then,
            // and a sideways drag across it selects photos. Disabling the page view's scroll,
            // rather than covering the page with a gesture, leaves that drag to the picker.
            .scrollDisabled(data.attachments.isEmpty)
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))

            TabBar()
        }
        .preferredColorScheme(.dark)
        .background(LinearGradient(
            gradient: Gradient(colors: [Color(.stone800), Color(.stone900)]),
            startPoint: .top,
            endPoint: .bottom
        ))
        .sheet(isPresented: $data.showsWhatsNew, onDismiss: data.recordWhatsNewSeen) {
            WhatsNewSheet(showsTips: FeatureTips.isEnabled)
        }
        .environment(data)
        .environment(data.editor)
    }
}

extension View {
    /// A drag gesture on the page takes precedence over the page view's swipe.
    func blocksSwipe(_ blocked: Bool) -> some View {
        contentShape(Rectangle())
            .gesture(DragGesture(), including: blocked ? .all : .subviews)
    }
}

struct TabBar: View {

    /// How long the Clear tab must be held to remove every photo.
    static let clearHoldDuration = 1.0
    /// Haptic taps while the Clear tab fills, each a little stronger than the last.
    static let clearHoldTicks = 20

    @Environment(DataModel.self) private var data
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    /// Bumped when Edit or Export is tapped before photos are picked: the Select tab shakes its head.
    @State private var nudgeCount = 0
    /// True while the Clear tab is held; resets on its own if the hold is abandoned or cancelled.
    @GestureState private var isHoldingClear = false
    /// How full the Clear tab is, 0...1.
    @State private var clearProgress = 0.0
    /// Haptic taps played so far in the current hold.
    @State private var clearHoldTick = 0
    /// Bumped when a hold clears the photos, for the haptic.
    @State private var clearCount = 0
    /// Bumped when a tap removes the current photo, for the haptic.
    @State private var removeCount = 0

    var body: some View {
        // With photos picked, the Select tab turns into Clear. A tap opens it, or once open removes the
        // current photo; a hold removes every photo from any tab.
        let clears = !data.attachments.isEmpty
        let items = HStack {
            ForEach(TabbedItems.allCases, id: \.self) { item in
                let isClear = item == .select && clears
                Button {
                    if isClear && data.selectedTab == .select {
                        removeCurrent()
                    } else if !item.needsPhotos || !data.attachments.isEmpty {
                        data.selectedTab = item
                    } else {
                        nudgeCount += 1
                        AccessibilityNotification.Announcement("Select some photos first").post()
                    }
                } label: {
                    TabItem(item: item, isActive: data.selectedTab == item, isClear: isClear,
                            clearProgress: isClear ? clearProgress : 0, glassNamespace: glassNamespace)
                        .keyframeAnimator(initialValue: Shake(), trigger: item == .select && !reduceMotion ? nudgeCount : 0) { tab, shake in
                            tab.offset(x: shake.offset).rotationEffect(.degrees(shake.angle))
                        } keyframes: { _ in
                            KeyframeTrack(\.offset) {
                                for offset in [-9.0, 8, -6, 4, -2, 0] {
                                    SpringKeyframe(offset, duration: 0.07, spring: .snappy)
                                }
                            }
                            KeyframeTrack(\.angle) {
                                for angle in [-5.0, 4, -3, 2, -1, 0] {
                                    SpringKeyframe(angle, duration: 0.07, spring: .snappy)
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
                .featureTip(isClear ? FeatureTips.current(ClearTip()) : nil)
                .simultaneousGesture(holdToClear, including: isClear ? .all : .subviews)
                .accessibilityLabel(isClear ? "Clear" : item.title)
                .accessibilityHint(isClear ? (data.selectedTab == .select ? "Removes this photo. Hold to remove all photos."
                                                                          : "Hold to remove all photos")
                                   : item.needsPhotos && data.attachments.isEmpty ? "Select some photos first" : "")
                .accessibilityAddTraits(data.selectedTab == item ? .isSelected : [])
                .accessibilityShowsLargeContentViewer()
                .accessibilityActions {
                    if isClear {
                        Button("Remove All Photos") { clearAll() }
                    }
                }
                .animation(.interactiveSpring, value: data.selectedTab)
            }
        }
        .animation(.interactiveSpring, value: clears)
        .frame(minHeight: 64)
        // Like the system tab bar: capped size, with the large content viewer beyond it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

        Group {
            if #available(iOS 26, *) {
                // Groups the tab pills so the active one morphs from tab to tab.
                // The bar itself isn't glass: glass can't sample glass layered on it.
                GlassEffectContainer {
                    items
                }
            } else {
                items
            }
        }
        .background(.accent.opacity(0.2), in: .rect(cornerRadius: 20))
        .onChange(of: isHoldingClear) { _, holding in
            withAnimation(holding ? .linear(duration: Self.clearHoldDuration) : .easeOut(duration: 0.2)) {
                clearProgress = holding ? 1 : 0
            }
        }
        .task(id: isHoldingClear) {
            clearHoldTick = 0
            guard isHoldingClear else { return }
            for tick in 1...Self.clearHoldTicks {
                do { try await Task.sleep(for: .seconds(Self.clearHoldDuration) / Self.clearHoldTicks) } catch { return }
                clearHoldTick = tick
            }
        }
        .sensoryFeedback(trigger: clearHoldTick) { _, tick in
            guard tick > 0 else { return nil }
            let fraction = Double(tick) / Double(Self.clearHoldTicks)
            // Firm from the first tap, so the hold is unmistakable, then heavier as the tab fills.
            let weight: SensoryFeedback.Weight = fraction < 1.0 / 3 ? .light : fraction < 2.0 / 3 ? .medium : .heavy
            return .impact(weight: weight, intensity: 0.5 + 0.5 * fraction)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: clearCount)
        .sensoryFeedback(.success, trigger: removeCount)
        .sensoryFeedback(.error, trigger: nudgeCount)
    }

    /// One frame of the Select tab's head shake.
    private struct Shake {
        var offset = 0.0
        var angle = 0.0
    }

    private var holdToClear: some Gesture {
        LongPressGesture(minimumDuration: Self.clearHoldDuration)
            .updating($isHoldingClear) { _, holding, _ in holding = true }
            .onEnded { _ in clearAll() }
    }

    private func removeCurrent() {
        // Also runs when a finger lifts after a hold has already cleared everything; there's nothing left to remove then.
        guard !data.attachments.isEmpty else { return }
        data.removeCurrent()
        removeCount += 1
    }

    private func clearAll() {
        ClearTip().invalidate(reason: .actionPerformed)
        data.clearSelection()
        data.selectedTab = .select
        clearCount += 1
    }
}

struct TabItem: View {

    let item: TabbedItems
    let isActive: Bool
    /// The Select tab standing in as Clear, in the destructive color.
    var isClear = false
    /// How far a hold on Clear has got, 0...1, shown as a fill across the tab.
    var clearProgress = 0.0
    /// Shared by every tab, so the one active pill moves between them.
    let glassNamespace: Namespace.ID

    var body: some View {
        let tint: Color = isClear ? .red : .accent
        let content = HStack {
            Image(systemName: isClear ? "trash" : item.iconName)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isActive ? .white : isClear ? .red : .stone500)
                .animation(.interactiveSpring, value: isActive)
            if isActive {
                Text(isClear ? "Clear" : item.title)
                    .font(.spaceMono(16))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .frame(minWidth: isActive ? 148 : 48, minHeight: 48)
        .background(alignment: .leading) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.red.opacity(0.6))
                    .frame(width: geometry.size.width * clearProgress)
            }
        }

        Group {
            if #available(iOS 26, *), isActive {
                content
                    .clipShape(.rect(cornerRadius: 16))
                    .glassEffect(.regular.tint(tint.opacity(0.5)).interactive(), in: .rect(cornerRadius: 16))
                    .glassEffectID("activeTab", in: glassNamespace)
            } else {
                content
                    .background(isActive ? tint.opacity(0.5) : .clear)
                    .clipShape(.rect(cornerRadius: 16))
            }
        }
        .animation(.interactiveSpring, value: isClear)
        .contentShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 8.0)
        .animation(.interactiveSpring, value: isActive)
    }
}

#Preview {
    MainView()
}
