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
                return "square.and.arrow.up"
        }
    }
}

struct MainView: View {
    
    @StateObject var data = DataModel()
    @State var selectedTab = 0
    
    var body: some View {
            VStack {
                
                /// Tabbed views
                TabView(selection: $selectedTab) {
                    SelectView()
                        .tag(0)
                    EditView()
                        .tag(1)
                    ExportView()
                        .tag(2)
                }
                
                /// Tab navigation
                VStack {
                    HStack {
                        ForEach((TabbedItems.allCases), id: \.self) {
                            item in Button {
                                selectedTab = item.rawValue
                            } label: {
                                CustomTabItem(imageName: item.iconName, title: item.title, isActive: (selectedTab == item.rawValue))
                            }
                            .animation(.interactiveSpring, value: selectedTab)
                        }
                        
                    }
                }
                .frame(height: 64)
                .background(.accent.opacity(0.2))
                .cornerRadius(20)
            }
            .background(Color(.stone900))
            .environmentObject(data)
        }
}

extension MainView {
    func CustomTabItem(imageName: String, title: String, isActive: Bool) -> some View {
        HStack {
            Image(systemName: imageName)
                .foregroundColor(isActive ? .white : .gray)
                .animation(.interactiveSpring, value: isActive)
            if isActive {
                Text(title)
                    .font(Font.custom("SpaceMono-Regular", size: 16))
                    .foregroundColor(isActive ? .white : .gray)
            }
        }
        .frame(width: isActive ? 148 : 48, height: 48)
        .background(isActive ? .accent.opacity(0.5) : .clear)
        .cornerRadius(16)
        .padding(.horizontal, 8.0)
        .animation(.interactiveSpring, value: isActive)
    }
}

#Preview {
    MainView().colorScheme(.dark)
}

