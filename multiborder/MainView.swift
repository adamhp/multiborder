//
//  MainView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

struct MainView: View {

    @State private var data = DataModel()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $data.selectedTab) {
                SelectView()
                    .tag(TabbedItems.select)
                EditView()
                    .tag(TabbedItems.edit)
                    .disabled(data.attachments.isEmpty)
                ExportView()
                    .tag(TabbedItems.export)
                    .disabled(data.attachments.isEmpty)
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
        .environment(data)
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

    @Environment(DataModel.self) private var data
    @Namespace private var glassNamespace

    var body: some View {
        let items = HStack {
            ForEach(TabbedItems.allCases, id: \.self) { item in
                Button {
                    if !item.needsPhotos || !data.attachments.isEmpty {
                        data.selectedTab = item
                    } else {
                        withAnimation {
                            data.helpTextShown = true
                        }
                        AccessibilityNotification.Announcement("Select some photos first").post()
                    }
                } label: {
                    TabItem(item: item, isActive: data.selectedTab == item, glassNamespace: glassNamespace)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityHint(item.needsPhotos && data.attachments.isEmpty ? "Select some photos first" : "")
                .accessibilityAddTraits(data.selectedTab == item ? .isSelected : [])
                .accessibilityShowsLargeContentViewer()
                .animation(.interactiveSpring, value: data.selectedTab)
            }
        }
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
    }
}

struct TabItem: View {

    let item: TabbedItems
    let isActive: Bool
    /// Shared by every tab, so the one active pill moves between them.
    let glassNamespace: Namespace.ID

    var body: some View {
        let content = HStack {
            Image(systemName: item.iconName)
                .foregroundStyle(isActive ? .white : .stone500)
                .animation(.interactiveSpring, value: isActive)
            if isActive {
                Text(item.title)
                    .font(.spaceMono(16))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 8)
        .frame(minWidth: isActive ? 148 : 48, minHeight: 48)

        Group {
            if #available(iOS 26, *), isActive {
                content
                    .glassEffect(.regular.tint(.accent.opacity(0.5)).interactive(), in: .rect(cornerRadius: 16))
                    .glassEffectID("activeTab", in: glassNamespace)
            } else {
                content
                    .background(isActive ? .accent.opacity(0.5) : .clear)
                    .clipShape(.rect(cornerRadius: 16))
            }
        }
        .contentShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 8.0)
        .animation(.interactiveSpring, value: isActive)
    }
}

#Preview {
    MainView()
}
