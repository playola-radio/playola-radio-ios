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
}
