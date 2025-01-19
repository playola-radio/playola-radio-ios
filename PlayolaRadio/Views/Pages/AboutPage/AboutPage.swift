//
//  AboutPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import SwiftUI
import Sharing

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

  init(canSendEmail: Bool = false,
       isShowingMailComposer: Bool = false,
       mailURL: URL? = nil,
       isShowingCannotOpenMailAlert: Bool = false,
       presentedAlert: PlayolaAlert? = nil,
       mailService: MailService = MailService()) {
    self.canSendEmail = canSendEmail
    self.isShowingMailComposer = isShowingMailComposer
    self.mailURL = mailURL
    self.isShowingCannotOpenMailAlert = isShowingCannotOpenMailAlert
    self.presentedAlert = presentedAlert
    self.mailService = mailService
  }

  // MARK: Actions
  func viewAppeared() async {
    self.canSendEmail = await mailService.canSendEmail()
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
    if self.showSecretStations {
      presentedAlert = .secretStationsTurnedOnAlert
    } else {
      presentedAlert = .secretStationsHiddenAlert
    }
  }

  // MARK: Other Functions
  private func sendEmail(recipientEmail: String, subject: String) {
    if canSendEmail {
      self.isShowingMailComposer = true
    } else if let url = mailService.mailSendURL(
      recipientEmail: recipientEmail, subject: subject) {
      mailService.openEmailUrl(url: url)
    } else {
      self.presentedAlert = .cannotOpenMailAlert
    }
  }
}



extension PlayolaAlert {
  static var cannotOpenMailAlert: PlayolaAlert {
    return PlayolaAlert(title: "Error Opening Mail",
                        message: "There was an error opening the email program",
                        dismissButton: .cancel(Text("OK")))
  }

  static var secretStationsTurnedOnAlert: PlayolaAlert {
    return PlayolaAlert(title: "Congratulations",
                        message: "Secret Stations Unlocked",
                        dismissButton: .cancel(Text("OK")))
  }

  static var secretStationsHiddenAlert: PlayolaAlert {
    return PlayolaAlert(title: "Secret Stations",
                        message: "Secret Stations Hidden",
                        dismissButton: .cancel(Text("OK")))
  }
}

struct AboutPage: View {
  @Bindable var model: AboutPageModel
  @Environment(\.openURL) var openURL

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack() {
        Image("LogoMark")
          .resizable()
          .scaledToFit()
          .frame(width: 50, height: 100)
          .padding(.top, 30)
          .onTapGesture(count: 10, perform: {
            model.handlePlayolaIconTapped10Times()
          })

        Image("PlayolaWordLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 200, height: 50)
          .padding(.bottom, 50)
          .onTapGesture(count: 10, perform: {
            //          toggleSecretStations()
          })

        (Text("Hey... Welcome to ")
          .font(.system(size: 24)) +

         Text("Playola.FM")
          .foregroundStyle(Color.init(hex: "A5A0F5"))
          .underline()
          .font(.system(size: 24))
        )

        Text("Please reach out and let us know what you think of our independent artist made radio stations.")
          .padding([.leading, .trailing], 35)
          .padding(.top, 5)
          .multilineTextAlignment(.center)
          .font(.system(size: 14))
          .bold()

        Text("We'd love to hear from you.")
          .padding(.top, 10)
          .font(.system(size: 14))
          .bold()

        Button(action: { model.feedbackButtonTapped() }) {
          Text("Let Us Know")
            .bold()
            .padding()
            .padding([.leading, .trailing], 20)
            .background(Color.playolaRed)
            .cornerRadius(15)
            .foregroundStyle(.black)
        }

        Spacer()

        Button(action: { model.waitingListButtonTapped() }) {
          Text("Join Waitlist")
            .bold()
            .padding()
            .padding(.horizontal, 20)
            .background(.white)
            .cornerRadius(15)
            .foregroundStyle(Color.init(hex: "6962EF"))
        }
        .padding(.bottom, -15)

        Text("Get early access to make your own station...")
          .padding(.top)
          .font(.system(size: 16))
          .padding(.bottom, -10)

        Text("coming soon.")
          .bold()
          .padding(.bottom, 20)
          .padding([.leading, .trailing], 50)

        HStack {
          Text("App Version: \(Bundle.main.releaseVersionNumber ?? "Unknown")")
            .padding(.leading)
            .font(.system(size: 12))
          Spacer()
        }
        .padding(.bottom, -20)
      }
    }
    .foregroundColor(.white)
    .onAppear {
      Task { await model.viewAppeared() }
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

#Preview {
  AboutPage(model: .init(canSendEmail: true, isShowingMailComposer: false))
}
