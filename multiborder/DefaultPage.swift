//
//  DefaultPage.swift
//  multiborder
//
//  Created by Adam Pearce on 9/5/24.
//

import SwiftUI

struct DefaultPage<Content: View>: View {
    
    let content: Content
    
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
