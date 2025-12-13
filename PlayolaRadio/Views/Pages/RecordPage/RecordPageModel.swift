//
//  RecordPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class RecordPageModel: ViewModel {
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  func viewAppeared() async {
    // TODO: Implement
  }
}
