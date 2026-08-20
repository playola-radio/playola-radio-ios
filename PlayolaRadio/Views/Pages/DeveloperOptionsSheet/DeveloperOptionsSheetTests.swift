//
//  DeveloperOptionsSheetTests.swift
//  PlayolaRadio
//
//  The hidden developer-options sheet: reached by tapping the profile image
//  10 times on the profile page; hosts the device-local sample-buffer
//  renderer override.
//

import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct DeveloperOptionsSheetTests {

  @Test
  func profileImageTapped10TimesPresentsDeveloperOptions() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = ContactPageModel()
    model.profileImageTapped10Times()

    guard case .developerOptions = coordinator.presentedSheet else {
      Issue.record(
        "expected developerOptions sheet, got \(String(describing: coordinator.presentedSheet))")
      return
    }
  }

  @Test
  func doneButtonDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = DeveloperOptionsSheetModel()
    coordinator.presentedSheet = .developerOptions(model)

    model.doneButtonTapped()

    #expect(coordinator.presentedSheet == nil)
  }

  @Test
  func localOverrideDefaultsOff() {
    @Shared(.sampleBufferRendererLocalOverride) var localOverride

    _ = DeveloperOptionsSheetModel()

    #expect(localOverride == false)
  }
}
