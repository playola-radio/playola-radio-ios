//
//  AboutPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import SwiftUI

@Observable
class AboutPageModel {
  // State
  var canSendEmail: Bool = false
  var isShowingMailComposer: Bool = false
  var mailURL: URL? = nil
  var isShowingCannotOpenMailAlert = false
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored var mailService = MailService()

  init(canSendEmail: Bool,
       isShowingMailComposer: Bool,
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

  func handleViewAppeared() async {
    self.canSendEmail = await mailService.canSendEmail()
  }

  func handleWaitingListButtonTapped() {
    if canSendEmail {
      self.isShowingMailComposer = true
    } else if let url = mailService.mailSendURL(recipientEmail: "waitlist@playola.fm", subject: "Add Me To The Waitlist") {
      Task { await UIApplication.shared.open(url) }
    } else {
      self.presentedAlert = .cannotOpenMailAlert
    }
  }
  func handleFeedbackButtonTapped() {}
  func handleViewDisappeared() {}
}

extension PlayolaAlert {
  static var cannotOpenMailAlert: PlayolaAlert {
    return PlayolaAlert(title: "Error Opening Mail",
                        message: "There was an error opening the email program",
                        dismissButton: .cancel(Text("Ok")))
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
            //          toggleSecretStations()
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

        Button(action: { model.handleFeedbackButtonTapped() }) {
          Text("Let Us Know")
            .bold()
            .padding()
            .padding([.leading, .trailing], 20)
            .background(Color.playolaRed)
            .cornerRadius(15)
            .foregroundStyle(.black)
        }

        Spacer()

        Button(action: { /*model.handleWaitingListButtonTapped()*/ model.presentedAlert = .cannotOpenMailAlert }) {
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
//    .onAppear {
//      Task { await model.handleViewAppeared() }
//    }
//    .sheet(isPresented: $store.isShowingMailComposer , content: {
//      Text("Here it is")
//    })
//    .alert(item: model.$presentedAlert) { playolaAlert in
//      playolaAlert.alert
//    }
    .alert(item: $model.presentedAlert) { $0.alert }
//    .alert($model.destination) { playolaAlert in
//      playolaAlert.alert
//    }

  }
}

//extension AlertState where Action == AboutPageReducer.Action.Alert {
//  static let cannotOpenMailFailure = AlertState(
//    title: TextState("Error Opening Mail"),
//    message: TextState("There was an error opening the email program."))
//}

#Preview {
  AboutPage(model: .init(canSendEmail: true, isShowingMailComposer: false))
}
