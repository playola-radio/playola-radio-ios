//
//  Toast.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Foundation

public struct PlayolaToast: Identifiable {
  public let id = UUID()
  public let message: String
  public let buttonTitle: String
  public let duration: TimeInterval
  public let action: (() -> Void)?

  public init(
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
  public static func == (lhs: PlayolaToast, rhs: PlayolaToast) -> Bool {
    lhs.id == rhs.id
  }
}
