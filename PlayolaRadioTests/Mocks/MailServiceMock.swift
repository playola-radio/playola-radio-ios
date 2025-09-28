//
//  MailServiceMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//
import Foundation

@testable import PlayolaRadio

class MailServiceMock: MailService {
  var shouldBeAbleToSendEmail: Bool = true
  var canCreateUrl: Bool = true

  var receivedEmail: String?
  var receivedSubject: String?

  var openedUrl: URL?

  init(shouldBeAbleToSendEmail: Bool = true, canCreateUrl: Bool = true) {
    self.shouldBeAbleToSendEmail = shouldBeAbleToSendEmail
    self.canCreateUrl = canCreateUrl
  }

  override func canSendEmail() async -> Bool {
    shouldBeAbleToSendEmail
  }

  override func openEmailUrl(url: URL) {
    openedUrl = url
  }

  override func mailSendURL(recipientEmail: String, subject: String) -> URL? {
    receivedEmail = recipientEmail
    receivedSubject = subject

    if canCreateUrl {
      return URL(string: "https://something")!
    } else {
      return nil
    }
  }
}

extension MailServiceMock {
  static var ableToSendEmail: MailServiceMock {
    MailServiceMock(shouldBeAbleToSendEmail: true)
  }

  static var unableToSendEmail: MailServiceMock {
    MailServiceMock(shouldBeAbleToSendEmail: false)
  }
}
