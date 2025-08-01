//
//  EditProfilePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/1/25.
//

import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class EditProfilePageTests: XCTestCase {
  func testInit_WithLoggedInUser_SetsInitialValues() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )

    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()

    XCTAssertEqual(model.firstName, "John")
    XCTAssertEqual(model.lastName, "Doe")
    XCTAssertEqual(model.email, "john@example.com")
  }

  func testInit_WithNoLoggedInUser_SetsEmptyValues() {
    @Shared(.auth) var auth = Auth()

    // When: Creating the model
    let model = EditProfilePageModel()
    model.viewAppeared()

    // Then: Model should be initialized with empty values
    XCTAssertEqual(model.firstName, "")
    XCTAssertEqual(model.lastName, "")
    XCTAssertEqual(model.email, "")
  }

  func testInit_WithPartialUserData_SetsAvailableValues() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: nil,  // No last name
      email: "jane@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    // When: Creating the model
    let model = EditProfilePageModel()
    model.viewAppeared()

    // Then: Model should be initialized with available data
    XCTAssertEqual(model.firstName, "Jane")
    XCTAssertEqual(model.lastName, "")
    XCTAssertEqual(model.email, "jane@example.com")
  }
}
