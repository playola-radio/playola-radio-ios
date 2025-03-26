//
//  NavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/21/25.
//
import SwiftUI
import Sharing

@Observable
@MainActor
class NavigationCoordinator: ViewModel {
  static let shared = NavigationCoordinator()

  @ObservationIgnored @Shared(.auth) var auth

  enum Paths {
    case about
    case listen
    case signIn
    case broadcast
  }
  var slideOutMenuIsShowing = false
  var activePath: Paths = .listen

  var aboutPath: [Path] = []
  var listenPath: [Path] = []
  var signInPath: [Path] = []
  var broadcastPath: [Path] = []

  var path: [Path] {
    get {
      if !auth.isLoggedIn {
        return self.signInPath
      }
      switch self.activePath {
      case .signIn:
        return signInPath
      case .about:
        return aboutPath
      case .listen:
        return listenPath
      case .broadcast:
        return broadcastPath
      }
    }
    set {
      switch self.activePath {
      case .about:
        aboutPath = newValue
      case .listen:
        listenPath = newValue
      case .signIn:
        signInPath = newValue
      case .broadcast:
        broadcastPath = newValue
      }
    }
  }

  enum Path: Hashable {
    case stationListPage(StationListModel)
    case aboutPage(AboutPageModel)
    case nowPlayingPage(NowPlayingPageModel)
    case signInPage(SignInPageModel)
    case broadcast(BroadcastBaseModel)
  }
}
