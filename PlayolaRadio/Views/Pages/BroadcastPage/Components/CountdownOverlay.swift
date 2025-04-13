//
//  CountdownOverlay.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/4/25.
//

import SwiftUI

struct CountdownOverlay: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                .frame(width: 120, height: 120)

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 120, height: 120)

            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white)
        }
        .transition(.scale)
    }
}

#Preview {
    ZStack {
        Color.black
        CountdownOverlay(count: 3)
    }
}
