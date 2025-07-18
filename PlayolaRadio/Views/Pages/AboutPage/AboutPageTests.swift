//
//  AboutPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class AboutPageTests: XCTestCase {
  func testPlayolaIcon_TurnsOnTheSecretStations() {
    let aboutPage = AboutPageModel()
    XCTAssertFalse(aboutPage.showSecretStations)
    aboutPage.handlePlayolaIconTapped10Times()
    XCTAssertTrue(aboutPage.showSecretStations)
    XCTAssertEqual(aboutPage.presentedAlert, .secretStationsTurnedOnAlert)
  }

  func testPlayolaIcon_TurnsOffTheSecretStations() {
    @Shared(.showSecretStations) var showSecretStations = true
    let aboutPage = AboutPageModel()
    XCTAssertTrue(aboutPage.showSecretStations)
    aboutPage.handlePlayolaIconTapped10Times()
    XCTAssertFalse(aboutPage.showSecretStations)
    XCTAssertEqual(aboutPage.presentedAlert, .secretStationsHiddenAlert)
  }

  func testViewAppeared_CorrectlySetsCanSendEmailWhenTrue() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: true))
    await aboutPage.viewAppeared()
    XCTAssertTrue(aboutPage.canSendEmail)
  }

  func testViewAppeared_CorrectlySetsCanSendEmailWhenFalse() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: false))
    await aboutPage.viewAppeared()
    XCTAssertFalse(aboutPage.canSendEmail)
  }

  // MARK: - Feedback Button Tests

  func testFeedbackButton_CorrectlySetsCanSendEmailWhenFalse() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: false))
    await aboutPage.viewAppeared()
    XCTAssertFalse(aboutPage.canSendEmail)
  }

  func testFeedbackButton_ShowsFeedbackEmailWhenMailComposerIsAvailable() async {
    let aboutPage = AboutPageModel(canSendEmail: true)
    aboutPage.feedbackButtonTapped()
    XCTAssertTrue(aboutPage.isShowingMailComposer)
  }

  func testFeedbackButton_ShowsFeedbackEmailWhenMailComposerIsUnavailable() async {
    let mailServiceMock = MailServiceMock(canCreateUrl: true)
    let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
    aboutPage.feedbackButtonTapped()
    XCTAssertEqual(mailServiceMock.receivedEmail, "feedback@playola.fm")
    XCTAssertEqual(mailServiceMock.receivedSubject, "What I Think About Playola")
  }

  func testFeedbackButton_ShowsAlertWhenMailCannotBeOpened() async {
    let mailServiceMock = MailServiceMock(canCreateUrl: false)
    let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
    aboutPage.feedbackButtonTapped()
    XCTAssertEqual(aboutPage.presentedAlert, .cannotOpenMailAlert)
  }

  // MARK: - Waitlist Button Tests

  func testWaitlistButton_ShowsFeedbackEmailWhenMailComposerIsAvailable() async {
    let aboutPage = AboutPageModel(canSendEmail: true)
    aboutPage.waitingListButtonTapped()
    XCTAssertTrue(aboutPage.isShowingMailComposer)
  }

  func testWaitlistButton_ShowsFeedbackEmailWhenMailComposerIsUnavailable() async {
    let mailServiceMock = MailServiceMock(canCreateUrl: true)
    let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
    aboutPage.waitingListButtonTapped()
    XCTAssertEqual(mailServiceMock.receivedEmail, "waitlist@playola.fm")
    XCTAssertEqual(mailServiceMock.receivedSubject, "Add Me To The Waitlist")
  }

  func testWaitlistButton_ShowsAlertWhenMailCannotBeOpened() async {
    let mailServiceMock = MailServiceMock(canCreateUrl: false)
    let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
    aboutPage.waitingListButtonTapped()
    XCTAssertEqual(aboutPage.presentedAlert, .cannotOpenMailAlert)
  }
}
