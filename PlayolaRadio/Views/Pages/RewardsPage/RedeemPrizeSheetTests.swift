//
//  RedeemPrizeSheetTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class RedeemPrizeSheetModelTests: XCTestCase {

  func testInitPreFillsVerifiedEmail() {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "test@example.com",
        verifiedEmail: "test@example.com"))

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    XCTAssertEqual(model.emailAddress, "test@example.com")
    XCTAssertTrue(model.hasVerifiedEmail)
  }

  func testInitUsesUnverifiedEmailWhenNoVerifiedEmail() {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "apple@privaterelay.com"))

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    XCTAssertEqual(model.emailAddress, "apple@privaterelay.com")
    XCTAssertFalse(model.hasVerifiedEmail)
  }

  func testInitLeavesEmailEmptyWhenNoAuth() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    XCTAssertEqual(model.emailAddress, "")
  }

  func testCanSubmitRequiresOptionAndEmail() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    XCTAssertFalse(model.canSubmit)

    let option = model.redeemOptions[0]
    model.optionTapped(option)
    XCTAssertFalse(model.canSubmit)

    model.emailAddress = "test@example.com"
    XCTAssertTrue(model.canSubmit)
  }

  func testOptionTappedSelectsOption() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)
    let option = model.redeemOptions[0]

    model.optionTapped(option)

    XCTAssertEqual(model.selectedOption, option)
    XCTAssertTrue(model.isSelected(option))
  }

  func testRedeemOptionsIncludesRegularPrizes() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    let options = model.redeemOptions
    XCTAssertFalse(options.isEmpty)
    XCTAssertTrue(options.allSatisfy { $0.stationId == nil })
  }

  func testSubmitWithVerifiedEmailSkipsUpdateUser() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "test@example.com",
        verifiedEmail: "test@example.com"))
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator

    let mockUserPrize = UserPrize(id: "up-1", userId: "user-1", prizeId: "p-1")
    let updateUserCalled = LockIsolated(false)
    let successCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.updateUser = { _, _, _, _ in
        updateUserCalled.withValue { $0 = true }
        return Auth()
      }
      $0.api.redeemPrize = { _, _, _ in
        return mockUserPrize
      }
    } operation: {
      RedeemPrizeSheetModel(
        prizeTier: .mock,
        onSuccess: { _ in
          successCalled.withValue { $0 = true }
        })
    }

    model.optionTapped(model.redeemOptions[0])

    await model.submitButtonTapped()

    XCTAssertFalse(updateUserCalled.value)
    XCTAssertTrue(successCalled.value)
    XCTAssertFalse(model.isSubmitting)
  }

  func testSubmitWithoutVerifiedEmailCallsUpdateUser() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "apple@privaterelay.com"))
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator

    let mockUserPrize = UserPrize(id: "up-1", userId: "user-1", prizeId: "p-1")
    let capturedVerifiedEmail = LockIsolated<String?>(nil)
    let successCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.updateUser = { _, _, _, verifiedEmail in
        capturedVerifiedEmail.withValue { $0 = verifiedEmail }
        return Auth(
          loggedInUser: LoggedInUser(
            id: "user-1", firstName: "Test", email: "apple@privaterelay.com",
            verifiedEmail: verifiedEmail))
      }
      $0.api.redeemPrize = { _, _, _ in
        return mockUserPrize
      }
    } operation: {
      RedeemPrizeSheetModel(
        prizeTier: .mock,
        onSuccess: { _ in
          successCalled.withValue { $0 = true }
        })
    }

    model.optionTapped(model.redeemOptions[0])
    model.emailAddress = "real@email.com"

    await model.submitButtonTapped()

    XCTAssertEqual(capturedVerifiedEmail.value, "real@email.com")
    XCTAssertTrue(successCalled.value)
    XCTAssertFalse(model.isSubmitting)
  }

  func testSubmitShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "test@example.com",
        verifiedEmail: "test@example.com"))

    let model = withDependencies {
      $0.api.redeemPrize = { _, _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      RedeemPrizeSheetModel(prizeTier: .mock)
    }

    model.optionTapped(model.redeemOptions[0])

    await model.submitButtonTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertFalse(model.isSubmitting)
  }
}
