//
//  AboutPageTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import XCTest

@testable import PlayolaRadio

final class AboutPageTests: XCTestCase {
  @MainActor
  func testShowsFeedbackEmailWhenMailComposerIsAvailable() async {
    let store = TestStore(initialState: AboutPageReducer.State()) {
      AboutPageReducer()
    } withDependencies: {
      $0.mailClient = MailClient(canSendEmail: {
        return true
      }, mailSendURL: { recipientEmail, subject in
        return nil
      })
    }
    await store.send(.viewAppeared)
    await store.receive(\.canSendEmailAnswered) {
      $0.canSendEmail = true
    }
    await store.send(.feedbackButtonTapped) {
      $0.isShowingMailComposer = true
    }
  }
  
  // TODO: Test OpensURL

  @MainActor
  func testShowsAlertWhenWaitlistWhenNoMailOptionWorkedforFeedback() async {
    let store = TestStore(initialState: AboutPageReducer.State()) {
      AboutPageReducer()
    } withDependencies: {
      $0.mailClient = MailClient(canSendEmail: {
        return false
      }, mailSendURL: { recipientEmail, subject in
        return nil
      })
    }
    await store.send(.viewAppeared)
    await store.receive(\.canSendEmailAnswered)
    await store.send(.feedbackButtonTapped) {
      $0.alert = .cannotOpenMailFailure
    }
  }

  @MainActor
  func testShowsWaitlistEmailWhenMailComposerIsAvailable() async {
    let store = TestStore(initialState: AboutPageReducer.State()) {
      AboutPageReducer()
    } withDependencies: {
      $0.mailClient = MailClient(canSendEmail: {
        return true
      }, mailSendURL: { recipientEmail, subject in
        return nil
      })
    }
    await store.send(.viewAppeared)
    await store.receive(\.canSendEmailAnswered) {
      $0.canSendEmail = true
    }
    await store.send(.waitingListButtonTapped) {
      $0.isShowingMailComposer = true
    }
  }

  // TODO: Test OpensURL

  @MainActor
  func testShowsAlertWhenWaitlistWhenNoMailOptionWorkedforWaitingList() async {
    let store = TestStore(initialState: AboutPageReducer.State()) {
      AboutPageReducer()
    } withDependencies: {
      $0.mailClient = MailClient(canSendEmail: {
        return false
      }, mailSendURL: { recipientEmail, subject in
        return nil
      })
    }
    await store.send(.viewAppeared)
    await store.receive(\.canSendEmailAnswered)
    await store.send(.waitingListButtonTapped) {
      $0.alert = .cannotOpenMailFailure
    }
  }
}
