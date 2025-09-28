//
//  EditProfilePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/1/25.
//

import Dependencies
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

  func testSaveButtonTapped_UpdateUserIsSuccessful() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let updatedUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "john@example.com"
    )
    let expectedAuth = Auth(currentUser: updatedUser, jwt: "new-jwt-token")

    let model = withDependencies {
      $0.api.updateUser = { jwtToken, firstName, lastName in
        XCTAssertEqual(jwtToken, auth.jwt)
        XCTAssertEqual(firstName, "Joe")
        XCTAssertEqual(lastName, "Jones")
        return expectedAuth
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      EditProfilePageModel()
    }

    model.viewAppeared()
    model.firstName = "Joe"
    model.lastName = "Jones"

    await model.saveButtonTapped()

    XCTAssertEqual(auth.currentUser?.firstName, "Jane")
    XCTAssertEqual(auth.currentUser?.lastName, "Smith")
    XCTAssertEqual(auth.jwt, "new-jwt-token")
    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert, PlayolaAlert.updateProfileSuccessfullAlert)
  }

  func testSaveButtonTapped_UpdateUserFails() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = withDependencies {
      $0.api.updateUser = { _, _, _ in
        throw APIError.dataNotValid
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      EditProfilePageModel()
    }

    model.viewAppeared()
    model.firstName = "Jane"
    model.lastName = "Smith"

    await model.saveButtonTapped()

    // Auth should remain unchanged on error
    XCTAssertEqual(auth.currentUser?.firstName, "John")
    XCTAssertEqual(auth.currentUser?.lastName, "Doe")
    XCTAssertEqual(auth.jwt, loggedInUser.jwt)

    // Error alert should be presented
    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert, PlayolaAlert.updateProfileErrorAlert)
  }

  func testSaveButtonTapped_NavigationPopsAfterSuccess() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

    // Clear navigation and add a test path
    navigationCoordinator.popToRoot()

    let updatedUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "john@example.com"
    )
    let expectedAuth = Auth(currentUser: updatedUser, jwt: "new-jwt-token")

    let model = withDependencies {
      $0.api.updateUser = { _, _, _ in
        expectedAuth
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      EditProfilePageModel()
    }

    // Add the model to the navigation stack
    navigationCoordinator.push(.editProfilePage(model))
    XCTAssertEqual(navigationCoordinator.path.count, 1)

    model.viewAppeared()
    model.firstName = "Jane"
    model.lastName = "Smith"

    await model.saveButtonTapped()

    // Verify navigation was popped
    XCTAssertEqual(navigationCoordinator.path.count, 0)

    // Clean up
    navigationCoordinator.popToRoot()
  }
}
