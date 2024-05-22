//
//  Mail.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation
import MessageUI
import UIKit
import SwiftUI

class EmailService: NSObject, MFMailComposeViewControllerDelegate {
  public static func createEmailUrl(to: String, subject: String, body: String? = nil) -> URL? {
    let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

    var gmailUrlStr = "googlegmail://co?to=\(to)&subject=\(subjectEncoded)"
    var outlookUrlStr = "ms-outlook://compose?to=\(to)&subject=\(subjectEncoded)"
    var yahooMailStr = "ymail://mail/compose?to=\(to)&subject=\(subjectEncoded)"
    var sparkUrlStr = "readdle-spark://compose?recipient=\(to)&subject=\(subjectEncoded)"
    var defaultUrlStr = "mailto:\(to)?subject=\(subjectEncoded)"

    if let body = body, let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      let additionalStr = "&body=\(bodyEncoded)"

      gmailUrlStr += additionalStr
      outlookUrlStr += additionalStr
      yahooMailStr += additionalStr
      sparkUrlStr += additionalStr
      defaultUrlStr += additionalStr
    }

    if let gmailUrl = URL(string: gmailUrlStr), UIApplication.shared.canOpenURL(gmailUrl) {
      return gmailUrl
    } else if let outlookUrl = URL(string: outlookUrlStr), UIApplication.shared.canOpenURL(outlookUrl) {
      return outlookUrl
    } else if let yahooMail = URL(string: yahooMailStr), UIApplication.shared.canOpenURL(yahooMail) {
      return yahooMail
    } else if let sparkUrl = URL(string: sparkUrlStr), UIApplication.shared.canOpenURL(sparkUrl) {
      return sparkUrl
    }
    return URL(string: defaultUrlStr)
  }

  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true)
  }
}

struct MailComposeView: UIViewControllerRepresentable {
  var toRecipients: [String]
  var mailBody: String
  var subject: String

  var didFinish: ()->()

  func makeCoordinator() -> Coordinator {
    return Coordinator(self)
  }

  func makeUIViewController(context: UIViewControllerRepresentableContext<MailComposeView>) -> MFMailComposeViewController {
    let mail = MFMailComposeViewController()
    mail.mailComposeDelegate = context.coordinator
    mail.setSubject(self.subject)
    mail.setToRecipients(self.toRecipients)
    mail.setMessageBody(self.mailBody, isHTML: true)
    return mail
  }

  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    var parent: MailComposeView

    init(_ mailController: MailComposeView) {
      self.parent = mailController
    }

    func mailComposeController(_ controller: MFMailComposeViewController, 
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
      parent.didFinish()
      controller.dismiss(animated: true)
    }
  }

  func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                              context: UIViewControllerRepresentableContext<MailComposeView>) {}
}
