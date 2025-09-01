//
//  ToastOverlayView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/31/25.
//

import Dependencies
import SwiftUI

@MainActor
struct ToastOverlayView: View {
  @Dependency(\.toast) var toast
  @State private var presentedToast: PlayolaToast?

  var body: some View {
    VStack {
      Spacer()
      if let currentToast = presentedToast {
        ToastView(toast: currentToast)
          .padding(.horizontal, 20)
          .padding(.bottom, 0)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.3), value: presentedToast)
    .task {
      // Monitor toast changes
      while !Task.isCancelled {
        if let currentToast = await toast.currentToast() {
          self.presentedToast = currentToast
        } else {
          self.presentedToast = nil
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }
}
