import Sharing
//
//  NavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/21/25.
//
import SwiftUI

@Observable
@MainActor
class NavigationCoordinator: ViewModel {
  static let shared = NavigationCoordinator()

  @ObservationIgnored @Shared(.auth) var auth

  enum Paths {
    case listen
    case signIn
  }
  var slideOutMenuIsShowing = false
  var activePath: Paths = .listen

  var listenPath: [Path] = []
  var signInPath: [Path] = []

  var path: [Path] {
    get {
      if !auth.isLoggedIn {
        return self.signInPath
      }
      switch self.activePath {
      case .signIn:
        return signInPath
      case .listen:
        return listenPath
      }
    }
    set {
      switch self.activePath {
      case .listen:
        listenPath = newValue
      case .signIn:
        signInPath = newValue
      }
    }
  }

  enum Path: Hashable {
    case stationListPage(StationListModel)
    case signInPage(SignInPageModel)
  }
}
