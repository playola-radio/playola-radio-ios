//
//  Toast.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Foundation

struct PlayolaToast: Identifiable {
  let id = UUID()
  let message: String
  let buttonTitle: String
  let duration: TimeInterval
  let action: (() -> Void)?

  init(
    message: String,
    buttonTitle: String,
    duration: TimeInterval = 3.0,
    action: (() -> Void)? = nil
  ) {
    self.message = message
    self.buttonTitle = buttonTitle
    self.duration = duration
    self.action = action
  }
}

extension PlayolaToast: Equatable {
  static func == (lhs: PlayolaToast, rhs: PlayolaToast) -> Bool {
    lhs.id == rhs.id
  }
}
