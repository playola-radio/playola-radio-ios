//
//  NavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/21/25.
//
import SwiftUI

@Observable
@MainActor
class NavigationCoordinator {
  static let shared = NavigationCoordinator()

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

  var path: [Path] {
    get {
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
