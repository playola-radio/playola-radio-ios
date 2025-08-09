import PlayolaCore
//
//  ContactPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/29/25.
//
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class ContactPageTests: XCTestCase {
  override static func setUp() {
    super.setUp()
    @Shared(.auth) var auth
  }

  func testOnLogOutTapped_StopsPlayerAndClearsAuth() {
    // Set up initial logged-in state using the new LoggedInUser initializer
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com",
      role: "user"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let stationPlayerMock = StationPlayerMock()
    let model = ContactPageModel(stationPlayer: stationPlayerMock)

    // Verify initial state
    XCTAssertTrue(auth.isLoggedIn)
    XCTAssertEqual(auth.currentUser?.firstName, "John")
    XCTAssertEqual(auth.currentUser?.lastName, "Doe")
    XCTAssertEqual(auth.currentUser?.email, "john@example.com")
    XCTAssertEqual(stationPlayerMock.stopCalledCount, 0)

    // Call sign out
    model.onLogOutTapped()

    // Verify station player was stopped
    XCTAssertEqual(stationPlayerMock.stopCalledCount, 1)

    // Verify auth was cleared
    XCTAssertFalse(auth.isLoggedIn)
    XCTAssertNil(auth.currentUser)
    XCTAssertNil(auth.jwt)
  }

  func testNameDisplay_ReturnsFullNameWhenLoggedIn() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "jane@example.com",
      role: "user"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = ContactPageModel()

    XCTAssertEqual(model.name, "Jane Smith")
  }

  func testNameDisplay_ReturnsAnonymousWhenNotLoggedIn() {
    @Shared(.auth) var auth = Auth()

    let model = ContactPageModel()

    XCTAssertEqual(model.name, "Anonymous")
  }

  func testEmailDisplay_ReturnsEmailWhenLoggedIn() {
    let loggedInUser = LoggedInUser(
      id: "456",
      firstName: "Bob",
      lastName: "Johnson",
      email: "bob@test.com",
      role: "admin"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = ContactPageModel()

    XCTAssertEqual(model.email, "bob@test.com")
  }

  func testEmailDisplay_ReturnsUnknownWhenNotLoggedIn() {
    @Shared(.auth) var auth = Auth()

    let model = ContactPageModel()

    XCTAssertEqual(model.email, "Unknown")
  }
}
