//
//  NewFeatureTileTests.swift
//  PlayolaRadio
//

import XCTest

@testable import PlayolaRadio

@MainActor
final class NewFeatureTileModelTests: XCTestCase {

  func testOnButtonTappedCallsButtonAction() async {
    var actionCalled = false

    let model = NewFeatureTileModel(
      buttonText: "Test Button",
      buttonAction: { actionCalled = true }
    )

    await model.onButtonTapped()

    XCTAssertTrue(actionCalled)
  }
}
