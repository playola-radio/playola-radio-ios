//
//  InvitationCodePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/18/25.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class InvitationCodePageTests: XCTestCase {
  func testInit_SetsInitialValues() async {
    // When: Creating the model
    let model = InvitationCodePageModel()

    // Then: Model should be initialized with default values
    XCTAssertEqual(model.invitationCode, "")
    XCTAssertNil(model.errorMessage)
    XCTAssertEqual(model.mode, .invitationCodeInput)
  }
}
