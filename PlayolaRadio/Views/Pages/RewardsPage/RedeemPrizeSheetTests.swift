//
//  RedeemPrizeSheetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct RedeemPrizeSheetModelTests {

  @Test
  func testInitPreFillsVerifiedEmail() {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "test@example.com",
        verifiedEmail: "test@example.com"))

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    #expect(model.emailAddress == "test@example.com")
    #expect(model.hasVerifiedEmail)
  }

  @Test
  func testInitUsesUnverifiedEmailWhenNoVerifiedEmail() {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "apple@privaterelay.com"))

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    #expect(model.emailAddress == "apple@privaterelay.com")
    #expect(!model.hasVerifiedEmail)
  }

  @Test
  func testInitLeavesEmailEmptyWhenNoAuth() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    #expect(model.emailAddress == "")
  }

  @Test
  func testCanSubmitRequiresOptionAndEmail() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    #expect(!model.canSubmit)

    let option = model.redeemOptions[0]
    model.optionTapped(option)
    #expect(!model.canSubmit)

    model.emailAddress = "test@example.com"
    #expect(model.canSubmit)
  }

  @Test
  func testOptionTappedSelectsOption() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)
    let option = model.redeemOptions[0]

    model.optionTapped(option)

    #expect(model.selectedOption == option)
    #expect(model.isSelected(option))
  }

  @Test
  func testRedeemOptionsIncludesRegularPrizes() {
    @Shared(.auth) var auth = Auth()

    let model = RedeemPrizeSheetModel(prizeTier: .mock)

    let options = model.redeemOptions
    #expect(!options.isEmpty)
    #expect(options.allSatisfy { $0.stationId == nil })
  }

  @Test
  func testSubmitWithVerifiedEmailSkipsUpdateUser() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "test@example.com",
        verifiedEmail: "test@example.com"))
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

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

    #expect(!updateUserCalled.value)
    #expect(successCalled.value)
    #expect(!model.isSubmitting)
  }

  @Test
  func testSubmitWithoutVerifiedEmailCallsUpdateUser() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(
        id: "user-1", firstName: "Test", email: "apple@privaterelay.com"))
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

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

    #expect(capturedVerifiedEmail.value == "real@email.com")
    #expect(successCalled.value)
    #expect(!model.isSubmitting)
  }

  @Test
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

    #expect(model.presentedAlert != nil)
    #expect(!model.isSubmitting)
  }
}
