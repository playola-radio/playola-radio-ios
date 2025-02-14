//
//  AboutPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

@testable import PlayolaRadio
import Sharing
import Testing

@MainActor
struct AboutPageTests {
  @Test("Tapping the icon 10 times changes the defaults and displays an alert")
  func testTurnsOnTheSecretStations() {
    let aboutPage = AboutPageModel()
    #expect(aboutPage.showSecretStations == false)
    aboutPage.handlePlayolaIconTapped10Times()
    #expect(aboutPage.showSecretStations == true)
    #expect(aboutPage.presentedAlert == .secretStationsTurnedOnAlert)
  }
  
  @Test("Tapping the icon 10 times changes the defaults and displays an alert")
  func testTurnsOffTheSecretStations() {
    @Shared(.showSecretStations) var showSecretStations = true
    let aboutPage = AboutPageModel()
    #expect(aboutPage.showSecretStations == true)
    aboutPage.handlePlayolaIconTapped10Times()
    #expect(aboutPage.showSecretStations == false)
    #expect(aboutPage.presentedAlert == .secretStationsHiddenAlert)
  }
  
  @Test("Correctly sets canSendEmail when true")
  func testCorrectlySetsCanSendEmailWhenTrue() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: true))
    await aboutPage.viewAppeared()
    #expect(aboutPage.canSendEmail == true)
  }
  
  @Test("Correctly sets canSendEmail when false")
  func testCorrectlySetsCanSendEmailWhenFalse() async {
    let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: false))
    await aboutPage.viewAppeared()
    #expect(aboutPage.canSendEmail == false)
  }
  
  @MainActor
  @Suite("Feedback Button")
  struct FeedbackTests {
    @Test("Correctly sets canSendEmail when false")
    func testCorrectlySetsCanSendEmailWhenFalse() async {
      let aboutPage = AboutPageModel(mailService: MailServiceMock(shouldBeAbleToSendEmail: false))
      await aboutPage.viewAppeared()
      #expect(aboutPage.canSendEmail == false)
    }
    
    @Test("Shows Feedback Email when MailComposer is available")
    func testShowsFeedbackEmailWhenMailComposerIsAvailable() async {
      let aboutPage = AboutPageModel(canSendEmail: true)
      aboutPage.feedbackButtonTapped()
      #expect(aboutPage.isShowingMailComposer == true)
    }
    
    @Test("Shows Feedback Email when MailComposer is unavailable but url can be created")
    func testShowsFeedbackEmailWhenMailComposerIsUnavavailable() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: true)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.feedbackButtonTapped()
      #expect(mailServiceMock.receivedEmail == "feedback@playola.fm")
      #expect(mailServiceMock.receivedSubject == "What I Think About Playola")
    }
    
    @Test("Shows Alert when no mail program could be opened")
    func testShowsFeedbackEmailWhenMailCannotBeOpened() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: false)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.feedbackButtonTapped()
      #expect(aboutPage.presentedAlert == .cannotOpenMailAlert)
    }
  }
  
  @MainActor
  @Suite("WaitlistButton")
  struct WaitlistButtonTests {
    @Test("Shows Feedback Email when MailComposer is available")
    func testShowsFeedbackEmailWhenMailComposerIsAvailable() async {
      let aboutPage = AboutPageModel(canSendEmail: true)
      aboutPage.waitingListButtonTapped()
      #expect(aboutPage.isShowingMailComposer == true)
    }
    
    @Test("Shows Feedback Email when MailComposer is unavailable but url can be created")
    func testShowsFeedbackEmailWhenMailComposerIsUnavavailable() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: true)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.waitingListButtonTapped()
      #expect(mailServiceMock.receivedEmail == "waitlist@playola.fm")
      #expect(mailServiceMock.receivedSubject == "Add Me To The Waitlist")
    }
    
    @Test("Shows Alert when no mail program could be opened")
    func testShowsFeedbackEmailWhenMailCannotBeOpened() async {
      let mailServiceMock = MailServiceMock(canCreateUrl: false)
      let aboutPage = AboutPageModel(canSendEmail: false, mailService: mailServiceMock)
      aboutPage.waitingListButtonTapped()
      #expect(aboutPage.presentedAlert == .cannotOpenMailAlert)
    }
  }
}
