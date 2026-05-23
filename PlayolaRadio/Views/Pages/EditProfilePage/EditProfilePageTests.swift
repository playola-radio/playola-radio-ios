//
//  EditProfilePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/1/25.
//

import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct EditProfilePageTests {
  @Test
  func testInitWithLoggedInUserSetsInitialValues() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )

    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()

    #expect(model.firstName == "John")
    #expect(model.lastName == "Doe")
    #expect(model.email == "john@example.com")
  }

  @Test
  func testInitWithNoLoggedInUserSetsEmptyValues() {
    @Shared(.auth) var auth = Auth()

    let model = EditProfilePageModel()
    model.viewAppeared()

    #expect(model.firstName == "")
    #expect(model.lastName == "")
    #expect(model.email == "")
  }

  @Test
  func testInitWithPartialUserDataSetsAvailableValues() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: nil,
      email: "jane@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()

    #expect(model.firstName == "Jane")
    #expect(model.lastName == "")
    #expect(model.email == "jane@example.com")
  }

  @Test
  func testSaveButtonEnabledNoChangesReturnsFalse() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()

    #expect(!model.isSaveButtonEnabled)
  }

  @Test
  func testSaveButtonEnabledFirstNameChangedReturnsTrue() {
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

    #expect(model.isSaveButtonEnabled)
  }

  @Test
  func testSaveButtonEnabledLastNameChangedReturnsTrue() {
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

    #expect(model.isSaveButtonEnabled)
  }

  @Test
  func testSaveButtonEnabledLastNameNilToEmptyReturnsFalse() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: nil,
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = EditProfilePageModel()
    model.viewAppeared()

    #expect(!model.isSaveButtonEnabled)
  }

  @Test
  func testSaveButtonEnabledLastNameEmptyToValueReturnsTrue() {
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

    #expect(model.isSaveButtonEnabled)
  }

  @Test
  func testSaveButtonEnabledRevertChangesReturnsFalse() {
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
    #expect(model.isSaveButtonEnabled)

    model.firstName = "John"

    #expect(!model.isSaveButtonEnabled)
  }

  @Test
  func testSaveButtonTappedUpdateUserIsSuccessful() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)
    let expectedJwt = auth.jwt

    let updatedUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "john@example.com"
    )
    let expectedAuth = Auth(currentUser: updatedUser, jwt: "new-jwt-token")

    let model = withDependencies {
      $0.api.updateUser = { jwtToken, firstName, lastName, _ in
        #expect(jwtToken == expectedJwt)
        #expect(firstName == "Joe")
        #expect(lastName == "Jones")
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

    #expect(auth.currentUser?.firstName == "Jane")
    #expect(auth.currentUser?.lastName == "Smith")
    #expect(auth.jwt == "new-jwt-token")
    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert == PlayolaAlert.updateProfileSuccessfullAlert)
  }

  @Test
  func testSaveButtonTappedUpdateUserFails() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = withDependencies {
      $0.api.updateUser = { _, _, _, _ in
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

    #expect(auth.currentUser?.firstName == "John")
    #expect(auth.currentUser?.lastName == "Doe")
    #expect(auth.jwt == loggedInUser.jwt)

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert == PlayolaAlert.updateProfileErrorAlert)
  }

  @Test
  func testSaveButtonTappedNavigationPopsAfterSuccess() async {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    navigationCoordinator.popToRoot()

    let updatedUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "john@example.com"
    )
    let expectedAuth = Auth(currentUser: updatedUser, jwt: "new-jwt-token")

    let model = withDependencies {
      $0.api.updateUser = { _, _, _, _ in
        return expectedAuth
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      EditProfilePageModel()
    }

    navigationCoordinator.push(.editProfilePage(model))
    #expect(navigationCoordinator.path.count == 1)

    model.viewAppeared()
    model.firstName = "Jane"
    model.lastName = "Smith"

    await model.saveButtonTapped()

    #expect(navigationCoordinator.path.count == 0)

    navigationCoordinator.popToRoot()
  }
}
