//
//  UpsideDownKeyboardView.swift
//  PlayolaRadio
//

import SwiftUI

struct UpsideDownKeyboardView: View {
  let model: UpsideDownKeyboardModel

  var body: some View {
    VStack(spacing: 10) {
      ForEach(model.rows) { row in
        HStack(spacing: 6) {
          ForEach(row.keys) { key in
            Button {
              model.keyTapped(key.action)
            } label: {
              Text(key.label)
                .font(.custom(FontNames.Inter_500_Medium, fixedSize: 18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.playolaSurfaceControl, in: RoundedRectangle(cornerRadius: 6))
            }
            .accessibilityLabel(key.accessibilityLabel)
            .accessibilityAddTraits(.isKeyboardKey)
          }
        }
      }
    }
    .padding(6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.playolaSurfaceSection)
  }
}
