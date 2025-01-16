//
//  PlayolaAlert.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import SwiftUI

class PlayolaAlert: Identifiable {
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
    return Alert(title: Text(self.title), message: messageView, dismissButton: self.dismissButton)
  }
}
