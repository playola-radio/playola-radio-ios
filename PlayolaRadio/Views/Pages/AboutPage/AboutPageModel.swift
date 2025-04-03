//
//  AboutPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

import Observation
import Foundation
import Sharing
import SwiftUI

@MainActor
@Observable
class AboutPageModel: ViewModel {
  // MARK: State

  var canSendEmail: Bool = false
  var isShowingMailComposer: Bool = false
  var mailURL: URL? = nil
  var isShowingCannotOpenMailAlert = false
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored var mailService = MailService()
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations
  var navigationCoordinator: NavigationCoordinator!

  init(canSendEmail: Bool = false,
       isShowingMailComposer: Bool = false,
       mailURL: URL? = nil,
       isShowingCannotOpenMailAlert: Bool = false,
       presentedAlert: PlayolaAlert? = nil,
       mailService: MailService = MailService(),
       navigationCoordinator: NavigationCoordinator = .shared)
  {
    self.canSendEmail = canSendEmail
    self.isShowingMailComposer = isShowingMailComposer
    self.mailURL = mailURL
    self.isShowingCannotOpenMailAlert = isShowingCannotOpenMailAlert
    self.presentedAlert = presentedAlert
    self.mailService = mailService
    self.navigationCoordinator = navigationCoordinator
  }

  // MARK: Actions

  func viewAppeared() async {
    canSendEmail = await mailService.canSendEmail()
  }

  func waitingListButtonTapped() {
    sendEmail(recipientEmail: "waitlist@playola.fm",
              subject: "Add Me To The Waitlist")
  }

  func feedbackButtonTapped() {
    sendEmail(recipientEmail: "feedback@playola.fm",
              subject: "What I Think About Playola")
  }

  func handlePlayolaIconTapped10Times() {
    $showSecretStations.withLock { $0 = !$0 }
    if showSecretStations {
      presentedAlert = .secretStationsTurnedOnAlert
    } else {
      presentedAlert = .secretStationsHiddenAlert
    }
  }

  func hamburgerButtonTapped() {
    navigationCoordinator.slideOutMenuIsShowing = true
  }

  // MARK: Other Functions

  private func sendEmail(recipientEmail: String, subject: String) {
    if canSendEmail {
      isShowingMailComposer = true
    } else if let url = mailService.mailSendURL(
      recipientEmail: recipientEmail, subject: subject
    ) {
      mailService.openEmailUrl(url: url)
    } else {
      presentedAlert = .cannotOpenMailAlert
    }
  }
}

extension PlayolaAlert {
  static var cannotOpenMailAlert: PlayolaAlert {
    PlayolaAlert(title: "Error Opening Mail",
                 message: "There was an error opening the email program",
                 dismissButton: .cancel(Text("OK")))
  }

  static var secretStationsTurnedOnAlert: PlayolaAlert {
    PlayolaAlert(title: "Congratulations",
                 message: "Secret Stations Unlocked",
                 dismissButton: .cancel(Text("OK")))
  }

  static var secretStationsHiddenAlert: PlayolaAlert {
    PlayolaAlert(title: "Secret Stations",
                 message: "Secret Stations Hidden",
                 dismissButton: .cancel(Text("OK")))
  }
}
