//
//  ClaimSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct ClaimSheetView: View {
  @Bindable var model: ClaimSheetModel

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        ClaimSheetContent(model: model)
          .frame(minHeight: proxy.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollDismissesKeyboard(.interactively)
    }
    .background(Color.playolaSurfaceBase.ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .presentationBackground(Color.playolaSurfaceBase)
    .interactiveDismissDisabled(model.isInteractiveDismissDisabled)
    .task { model.viewAppeared() }
  }
}
