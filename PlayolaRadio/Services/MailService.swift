//
//  MailClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation
import MessageUI

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
