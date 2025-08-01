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
    // Given: A logged in user with only some profile data
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

  func testSaveButtonEnabled_NoChanges_ReturnsFalse() {
    // Given: A logged in user
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    // When: Creating the model with no changes
    let model = EditProfilePageModel()
    model.viewAppeared()

    // Then: Save button should be disabled
    XCTAssertFalse(model.isSaveButtonEnabled)
  }

  func testSaveButtonEnabled_FirstNameChanged_ReturnsTrue() {
    // Given: A logged in user
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    // When: Creating the model and changing firstName
    let model = EditProfilePageModel()
    model.viewAppeared()
    model.firstName = "Jane"

    // Then: Save button should be enabled
    XCTAssertTrue(model.isSaveButtonEnabled)
  }

  func testSaveButtonEnabled_LastNameChanged_ReturnsTrue() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()
    model.lastName = "Smith"

    XCTAssertTrue(model.isSaveButtonEnabled)
  }

  func testSaveButtonEnabled_LastNameNilToEmpty_ReturnsFalse() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: nil,
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()

    XCTAssertFalse(model.isSaveButtonEnabled)
  }

  func testSaveButtonEnabled_LastNameEmptyToValue_ReturnsTrue() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: nil,
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()
    model.lastName = "Doe"

    XCTAssertTrue(model.isSaveButtonEnabled)
  }

  func testSaveButtonEnabled_RevertChanges_ReturnsFalse() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()
    model.firstName = "Jane"
    XCTAssertTrue(model.isSaveButtonEnabled)  // Should be enabled after change

    model.firstName = "John"  // Revert back

    XCTAssertFalse(model.isSaveButtonEnabled)
  }
}
