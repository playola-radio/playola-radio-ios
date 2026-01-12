//
//  NewFeatureTileModel.swift
//  PlayolaRadio
//

import SwiftUI

@MainActor
@Observable
class NewFeatureTileModel: ViewModel {
  var iconName: String
  var isSystemImage: Bool
  var label: String
  var content: String
  var paragraph: String?
  var buttonText: String?
  var buttonAction: (() async -> Void)?

  init(
    iconName: String = "listening-time-icon",
    isSystemImage: Bool = false,
    label: String = "New Feature",
    content: String = "Coming Soon",
    paragraph: String? = nil,
    buttonText: String? = nil,
    buttonAction: (() async -> Void)? = nil
  ) {
    self.iconName = iconName
    self.isSystemImage = isSystemImage
    self.label = label
    self.content = content
    self.paragraph = paragraph
    self.buttonText = buttonText
    self.buttonAction = buttonAction
    super.init()
  }

  func onButtonTapped() async {
    await buttonAction?()
  }
}
