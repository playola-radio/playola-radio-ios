//
//  MailClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation
import ComposableArchitecture
import MessageUI

struct MailClient {
  var canSendEmail: @Sendable () async -> Bool
  var mailSendURL: @Sendable (_ recipientEmail: String, _ subject: String) -> URL?
}

extension MailClient: DependencyKey {
  static var liveValue: MailClient {
    return MailClient {
      return await MFMailComposeViewController.canSendMail()
    } mailSendURL: { recipientEmail, subject in
      return EmailService.createEmailUrl(to: recipientEmail, subject: subject)
    }
  }

  static var previewValue: MailClient {
    return Self {
      return true
    } mailSendURL: { recipientEmail, subject in
      return EmailService.createEmailUrl(to: recipientEmail, subject: subject)
    }
  }

  static var testValue: MailClient {
    return Self {
      return true
    } mailSendURL: { recipientEmail, subject in
      return EmailService.createEmailUrl(to: recipientEmail, subject: subject)
    }
  }
}

extension DependencyValues {
  var mailClient: MailClient {
    get { self[MailClient.self] }
    set { self [MailClient.self] = newValue }
  }
}

public class MailService {
  func canSendEmail() async -> Bool {
    return await MFMailComposeViewController.canSendMail()
  }

  func mailSendURL(recipientEmail: String, subject: String) -> URL? {
    return EmailService.createEmailUrl(to: recipientEmail, subject: subject)
  }

  func openEmailUrl(url: URL) {
    UIApplication.shared.open(url)
  }
}
