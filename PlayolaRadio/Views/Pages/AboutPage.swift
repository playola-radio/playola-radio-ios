//
//  AboutPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct AboutPageReducer {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var alert: AlertState<Action.Alert>?
    var canSendEmail:Bool = false
    var isShowingMailComposer:Bool = false
    var mailURL: URL? = nil
  }

  enum Action: BindableAction, Equatable, Sendable {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case waitingListButtonTapped
    case feedbackButtonTapped
    case viewAppeared
    case canSendEmailAnswered(Bool)

    @CasePathable
    enum Alert: Equatable {}
  }

  @Dependency(\.mailClient) var mailClient

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .viewAppeared:
        return .run { send in
          let canSend = await mailClient.canSendEmail()
          await send(.canSendEmailAnswered(canSend))
        }

      case .waitingListButtonTapped:
        if state.canSendEmail {
          state.isShowingMailComposer = true
        } else if let url = mailClient.mailSendURL("waitlist@playola.fm", "Add Me To The Waitlist") {
          UIApplication.shared.open(url)
        } else {
          state.alert = .cannotOpenMailFailure
        }
        return .none

      case .feedbackButtonTapped:
        if state.canSendEmail {
          state.isShowingMailComposer = true
        } else if let url = mailClient.mailSendURL("feedback@playola.fm", "Playola Feedback") {
          UIApplication.shared.open(url)
        } else {
          state.alert = .cannotOpenMailFailure
        }
        return .none

      case let .canSendEmailAnswered(canSend):
        state.canSendEmail = canSend
        return .none
      
      case .binding(_):
        return .none

      case .alert:
        return .none
      }
    }
  }
}

struct AboutPage: View {
  @Bindable var store: StoreOf<AboutPageReducer>
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

        Button(action: { store.send(.feedbackButtonTapped) }) {
          Text("Let Us Know")
            .bold()
            .padding()
            .padding([.leading, .trailing], 20)
            .background(Color.playolaRed)
            .cornerRadius(15)
            .foregroundStyle(.black)
        }

        Spacer()

        Button(action: { store.send(.waitingListButtonTapped) }) {
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
      store.send(.viewAppeared)
    }
    .sheet(isPresented: $store.isShowingMailComposer , content: {
      Text("Here it is")
    })
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

extension AlertState where Action == AboutPageReducer.Action.Alert {
  static let cannotOpenMailFailure = AlertState(
    title: TextState("Error Opening Mail"),
    message: TextState("There was an error opening the email program."))
}

#Preview {
  AboutPage(store: Store(initialState: AboutPageReducer.State()) {
    AboutPageReducer()
  })
}
