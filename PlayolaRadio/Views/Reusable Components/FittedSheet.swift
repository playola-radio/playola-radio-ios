//
//  FittedSheet.swift
//  PlayolaRadio
//

import SwiftUI

struct FittedSheet<Content: View>: View {
  @State private var contentHeight: CGFloat = 400
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ScrollView {
      content
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          contentHeight = $0
        }
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(Color.playolaSurfaceSection.ignoresSafeArea())
    .presentationDetents([.height(max(contentHeight, 1))])
    .presentationBackground(Color.playolaSurfaceSection)
    .presentationCornerRadius(16)
    .presentationDragIndicator(.hidden)
  }
}
