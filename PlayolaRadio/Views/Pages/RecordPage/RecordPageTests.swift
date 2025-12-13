//
//  RecordPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class RecordPageTests: XCTestCase {
  override func setUp() {
    super.setUp()
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    coordinator.presentedSheet = nil
  }

  func testOnDoneTapped_DismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

    XCTAssertNotNil(coordinator.presentedSheet)

    model.onDoneTapped()

    XCTAssertNil(coordinator.presentedSheet)
  }
}
