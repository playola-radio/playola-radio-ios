//
//  SectionIndexView.swift
//  PlayolaRadio
//

import SwiftUI

struct SectionIndexView: View {
  let letters: [String]
  let onSelectLetter: (String) -> Void

  @GestureState private var isDragging = false
  @State private var selectedLetter: String?

  var body: some View {
    VStack(spacing: 2) {
      ForEach(letters, id: \.self) { letter in
        Text(letter)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(selectedLetter == letter ? .playolaRed : .playolaGray)
          .frame(width: 16, height: 14)
      }
    }
    .padding(.vertical, 4)
    .background(Color.black.opacity(0.3))
    .cornerRadius(8)
    .gesture(
      DragGesture(minimumDistance: 0)
        .updating($isDragging) { _, state, _ in
          state = true
        }
        .onChanged { value in
          let letterHeight: CGFloat = 16
          let index = Int(value.location.y / letterHeight)
          if index >= 0 && index < letters.count {
            let letter = letters[index]
            if selectedLetter != letter {
              selectedLetter = letter
              onSelectLetter(letter)
            }
          }
        }
        .onEnded { _ in
          selectedLetter = nil
        }
    )
  }
}
