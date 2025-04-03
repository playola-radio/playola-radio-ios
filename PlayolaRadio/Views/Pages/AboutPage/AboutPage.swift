//
//  AboutPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Sharing
import SwiftUI


@MainActor
struct AboutPage: View {
  @Bindable var model: AboutPageModel
  @Environment(\.openURL) var openURL

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack {
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

        Text("Hey... Welcome to ")
          .font(.system(size: 24)) +

        Text("Playola.FM")
          .foregroundStyle(Color(hex: "A5A0F5"))
          .underline()
          .font(.system(size: 24))

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
            .foregroundStyle(Color(hex: "6962EF"))
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
    .navigationBarHidden(false)
    .toolbar(content: {
      ToolbarItem(placement: .topBarLeading) {
        Image(systemName: "line.3.horizontal")
          .foregroundColor(.white)
          .onTapGesture {
            model.hamburgerButtonTapped()
          }
      }
    })
  }
}

#Preview {
  AboutPage(model: .init(canSendEmail: true, isShowingMailComposer: false))
}
