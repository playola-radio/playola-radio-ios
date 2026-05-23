//
//  NewFeatureTileTests.swift
//  PlayolaRadio
//

import Testing

@testable import PlayolaRadio

@MainActor
struct NewFeatureTileModelTests {

  @Test
  func testOnButtonTappedCallsButtonAction() async {
    var actionCalled = false

    let model = NewFeatureTileModel(
      buttonText: "Test Button",
      buttonAction: { actionCalled = true }
    )

    await model.onButtonTapped()

    #expect(actionCalled)
  }
}
