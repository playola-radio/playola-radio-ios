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
  }
  var slideOutMenuIsShowing = false
  var activePath: Paths = .signIn

  var aboutPath: [Path] = []
  var listenPath: [Path] = []
  var signInPath: [Path] = []

  public func setupPaths() {
    aboutPath = [.aboutPage(AboutPageModel())]
    listenPath = [.stationListPage(StationListModel())]
    signInPath = [.signInPage(SignInPageModel())]
  }

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
      }
    }
  }

  enum Path: Hashable {
    case stationListPage(StationListModel)
    case aboutPage(AboutPageModel)
    case nowPlayingPage(NowPlayingPageModel)
    case signInPage(SignInPageModel)
  }
}
