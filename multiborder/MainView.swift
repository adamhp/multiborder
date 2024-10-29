//
//  MainView.swift
//  multiborder
//
//  Created by Adam Pearce on 6/14/24.
//

import SwiftUI

enum TabbedItems: Int, CaseIterable{
    case select = 0
    case edit
    case export
        
    var title: String {
        switch self {
            case .select:
                return "Select"
            case .edit:
                return "Edit"
            case .export:
                return "Export"
        }
    }
    
    var iconName: String{
        switch self {
            case .select:
                return "photo.badge.plus"
            case .edit:
                return "slider.horizontal.3"
            case .export:
                return "square.and.arrow.down"
        }
    }
}

struct MainView: View {

    @StateObject var data = DataModel()
    
    var body: some View {
        VStack(spacing: 0) {
                /// Tabbed views
            TabView(selection: $data.selectedTab) {
                if data.attachments.count > 0 {
                    SelectView()
                        .tag(0)
                        .contentShape(Rectangle())
                    EditView()
                        .tag(1)
                        .disabled(data.selection.count == 0)
                        .contentShape(Rectangle())
                    ExportView()
                        .tag(2)
                        .disabled(data.selection.count == 0)
                        .contentShape(Rectangle())
                } else {
                    SelectView()
                        .tag(0)
                        .contentShape(Rectangle())
                        .gesture(DragGesture())
                    EditView()
                        .tag(1)
                        .disabled(data.selection.count == 0)
                        .contentShape(Rectangle())
                        .gesture(DragGesture())
                    ExportView()
                        .tag(2)
                        .disabled(data.selection.count == 0)
                        .contentShape(Rectangle())
                        .gesture(DragGesture())
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))
            
            /// Tab navigation
            VStack {
                HStack {
                    ForEach((TabbedItems.allCases), id: \.self) {
                        item in Button {
                            switch item.title {
                                case "Select":
                                    data.selectedTab = item.rawValue
                                case "Edit":
                                    if data.selection.count > 0 {
                                        data.selectedTab = item.rawValue
                                    } else {
                                        withAnimation {
                                            data.helpTextShown = true
                                        }
                                    }
                                case "Export":
                                    if data.selection.count > 0 {
                                        data.selectedTab = item.rawValue
                                    } else {
                                        withAnimation {
                                            data.helpTextShown = true
                                        }
                                    }
                                default:
                                    data.selectedTab = item.rawValue
                            }
                        } label: {
                            CustomTabItem(imageName: item.iconName, title: item.title, isActive: (data.selectedTab == item.rawValue))
                        }
                        .animation(.interactiveSpring, value: data.selectedTab)
                    }
                    
                }
            }
            .frame(height: 64)
            .background(.accent.opacity(0.2))
            .cornerRadius(20)
        }
        .colorScheme(.dark)
        .background(LinearGradient(
            gradient: Gradient(colors: [Color(.stone800), Color(.stone900)]),
            startPoint: .top,
            endPoint: .bottom
        ))
        .onAppear(perform: {
            data.tryLoadDefaults()
        })
        .environmentObject(data)
    }
}

extension MainView {
    func CustomTabItem(imageName: String, title: String, isActive: Bool) -> some View {
        HStack {
            Image(systemName: imageName)
                .foregroundColor(isActive ? .white : .stone500)
                .animation(.interactiveSpring, value: isActive)
            if isActive {
                Text(title)
                    .font(Font.custom("SpaceMono-Regular", size: 16))
                    .foregroundColor(isActive ? .white : .gray)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .frame(width: isActive ? 148 : 48, height: 48)
        .background(isActive ? .accent.opacity(0.5) : .clear)
        .cornerRadius(16)
        .padding(.horizontal, 8.0)
        .animation(.interactiveSpring, value: isActive)
    }
}

#Preview {
    MainView()
}
