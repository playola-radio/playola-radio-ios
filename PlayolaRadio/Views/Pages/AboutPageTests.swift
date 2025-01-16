//
//  Untitled.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import Testing
@testable import PlayolaRadio

struct AboutPageTests {

  @Test("Correctly sets canSendEmail when true")
  func testCorrectlySetsCanSendEmailWhenTrue() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: true))
    await aboutPage.handleViewAppeared()
    #expect(aboutPage.canSendEmail == true)
  }

  @Test("Correctly sets canSendEmail when false")
  func testCorrectlySetsCanSendEmailWhenFalse() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: false))
    await aboutPage.handleViewAppeared()
    #expect(aboutPage.canSendEmail == false)
  }

  @Suite("Feedback Button")
  struct FeedbackTests {

    @Test("Correctly sets canSendEmail when false")
    func testCorrectlySetsCanSendEmailWhenFalse() async {
      let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: false))
      await aboutPage.handleViewAppeared()
      #expect(aboutPage.canSendEmail == false)
    }

    @Test("Shows Feedback Email when MailComposer is available")
    func testShowsFeedbackEmailWhenMailComposerIsAvailable() async {
      let aboutPage = AboutPageModel(canSendEmail: true)
      aboutPage.handleFeedbackButtonTapped()
      #expect(aboutPage.isShowingMailComposer == true)
    }

    @Test("Shows Feedback Email when MailComposer is unavailable but url can be created")
    func testShowsFeedbackEmailWhenMailComposerIsUnavavailable() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: true)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.handleFeedbackButtonTapped()
      #expect(mailServiceMock.receivedEmail == "feedback@playola.fm")
      #expect(mailServiceMock.receivedSubject == "What I Think About Playola")
    }

    @Test("Shows Alert when no mail program could be opened")
    func testShowsFeedbackEmailWhenMailCannotBeOpened() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: false)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.handleFeedbackButtonTapped()
      #expect(aboutPage.presentedAlert == .cannotOpenMailAlert)
    }
  }

  @Suite("WaitlistButton")
  struct WaitlistButtonTests {
    @Test("Shows Feedback Email when MailComposer is available")
    func testShowsFeedbackEmailWhenMailComposerIsAvailable() async {
      let aboutPage = AboutPageModel(canSendEmail: true)
      aboutPage.handleWaitingListButtonTapped()
      #expect(aboutPage.isShowingMailComposer == true)
    }

    @Test("Shows Feedback Email when MailComposer is unavailable but url can be created")
    func testShowsFeedbackEmailWhenMailComposerIsUnavavailable() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: true)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.handleWaitingListButtonTapped()
      #expect(mailServiceMock.receivedEmail == "waitlist@playola.fm")
      #expect(mailServiceMock.receivedSubject == "Add Me To The Waitlist")
    }

    @Test("Shows Alert when no mail program could be opened")
    func testShowsFeedbackEmailWhenMailCannotBeOpened() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: false)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.handleWaitingListButtonTapped()
      #expect(aboutPage.presentedAlert == .cannotOpenMailAlert)
    }
  }
}
