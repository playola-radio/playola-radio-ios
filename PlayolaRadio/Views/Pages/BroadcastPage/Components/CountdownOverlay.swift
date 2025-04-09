//
//  CountdownOverlay.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/4/25.
//

import SwiftUI

struct CountdownOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            Text(text)
                .font(.system(size: 120, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(1.0)
                .transition(.scale(scale: 0.1).combined(with: .opacity))
        }
    }
}

#Preview {
    CountdownOverlay(text: "3")
}
