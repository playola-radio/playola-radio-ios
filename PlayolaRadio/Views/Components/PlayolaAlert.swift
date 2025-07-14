//
//  PlayolaAlert.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import SwiftUI

class PlayolaAlert: Equatable, Identifiable, Hashable {
  static func == (lhs: PlayolaAlert, rhs: PlayolaAlert) -> Bool {
    lhs.title == rhs.title && lhs.message == rhs.message
  }
  
  let title: String
  let message: String?
  let dismissButton: Alert.Button?
  
  init(title: String, message: String?, dismissButton: Alert.Button?) {
    self.title = title
    self.message = message
    self.dismissButton = dismissButton
  }
  
  var alert: Alert {
    var messageView: Text?
    if let message {
      messageView = Text(message)
    }
    return Alert(title: Text(title), message: messageView, dismissButton: dismissButton)
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(title)
    hasher.combine(message)
  }
}
