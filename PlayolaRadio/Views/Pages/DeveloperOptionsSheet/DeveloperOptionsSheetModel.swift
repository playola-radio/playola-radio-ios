//
//  DeveloperOptionsSheetModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/20/26.
//

import Foundation
import Observation
import Sharing

@MainActor
@Observable
class DeveloperOptionsSheetModel: ViewModel {

  // MARK: - Shared State

  @ObservationIgnored @Shared(.sampleBufferRendererLocalOverride)
  var sampleBufferRendererLocalOverride: Bool = false
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  let navigationTitle = "Developer Options"
  let doneButtonText = "Done"
  let sampleBufferRendererTitle = "AirPlay-2 Renderer (this device)"
  let sampleBufferRendererDetail =
    "Forces the sample-buffer render backend on this device, regardless of the "
    + "server flag. The renderer locks at the first play of a session, so a "
    + "change here takes effect on the next app launch if audio has already "
    + "played. The server can still disable the backend remotely."

  // MARK: - User Actions

  func doneButtonTapped() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }
}
