//
//  MailClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import Foundation
import MessageUI

struct MailClient {
    var canSendEmail: @Sendable () async -> Bool
    var mailSendURL: @Sendable (_ recipientEmail: String, _ subject: String) -> URL?
}

extension MailClient: DependencyKey {
    static var liveValue: MailClient {
        MailClient {
            await MFMailComposeViewController.canSendMail()
        } mailSendURL: { recipientEmail, subject in
            EmailService.createEmailUrl(to: recipientEmail, subject: subject)
        }
    }

    static var previewValue: MailClient {
        Self {
            true
        } mailSendURL: { recipientEmail, subject in
            EmailService.createEmailUrl(to: recipientEmail, subject: subject)
        }
    }

    static var testValue: MailClient {
        Self {
            true
        } mailSendURL: { recipientEmail, subject in
            EmailService.createEmailUrl(to: recipientEmail, subject: subject)
        }
    }
}

extension DependencyValues {
    var mailClient: MailClient {
        get { self[MailClient.self] }
        set { self[MailClient.self] = newValue }
    }
}

public class MailService {
    func canSendEmail() async -> Bool {
        await MFMailComposeViewController.canSendMail()
    }

    func mailSendURL(recipientEmail: String, subject: String) -> URL? {
        EmailService.createEmailUrl(to: recipientEmail, subject: subject)
    }

    func openEmailUrl(url: URL) {
        UIApplication.shared.open(url)
    }
}
