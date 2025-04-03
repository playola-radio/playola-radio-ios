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
  @MainActor
  static let shared = NavigationCoordinator()
    @ObservationIgnored @Shared(.auth) var auth

    enum Paths {
        case about
        case listen
        case signIn
        case broadcastBase
    }

    enum BroadcastTabs {
      case schedule
      case songs
      case none
    }
    var slideOutMenuIsShowing = false
    var activePath: Paths = .listen
    var activeBroadcastTab: BroadcastTabs = .none

    var aboutPath: [Path] = []
    var listenPath: [Path] = []
    var signInPath: [Path] = []
    var broadcastPath: [Path] = []
    var broadcastScheduleTabPath: [Path] = []
    var broadcastSongsTabPath: [Path] = []

  @ObservationIgnored lazy var broadcastStationSelectionPageModel = BroadcastStationSelectionPageModel()

    override init() {
        super.init()
        if auth.isLoggedIn {
            self.activePath = .listen
        } else {
            self.activePath = .signIn
        }
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
            case .broadcastBase:
              switch self.activeBroadcastTab {
              case .schedule:
                return broadcastScheduleTabPath
              case .songs:
                return broadcastSongsTabPath
              case .none:
                return broadcastPath
              }
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
            case .broadcastBase:
                broadcastPath = newValue
            }
        }
    }

    @ViewBuilder
    func createNavigationStack() -> some View {
        // Create a Bindable wrapper for self since we're in a non-View context
        let binding = Bindable(self).path

        NavigationStack(path: binding) {
            Group {
                switch activePath {
                case .about:
                    AboutPage(model: AboutPageModel())
                case .listen:
                    StationListPage(model: StationListModel())
                case .signIn:
                    SignInPage(model: SignInPageModel())
                case .broadcastBase:
                  BroadcastStationSelectionPage(model: broadcastStationSelectionPageModel)
                }
            }
            .navigationDestination(for: Path.self) { path in
                switch path {
                case let .aboutPage(model):
                    AboutPage(model: model)
                case let .stationListPage(model):
                    StationListPage(model: model)
                case let .nowPlayingPage(model):
                    NowPlayingView(model: model)
                case let .signInPage(model):
                    SignInPage(model: model)
                case let .broadcastBase(model: model):
                    BroadcastBasePage(model: model)
                case let .broadcastPage(model: model):
                    BroadcastPage(model: model)
                case let .broadcastStationSelectionPage(model: model):
                  BroadcastStationSelectionPage(model: model)
                }
            }
        }
        .accentColor(.white)
    }

    enum Path: Hashable {
        case stationListPage(StationListModel)
        case aboutPage(AboutPageModel)
        case nowPlayingPage(NowPlayingPageModel)
        case signInPage(SignInPageModel)
        case broadcastBase(BroadcastBaseModel)
        case broadcastPage(BroadcastPageModel)
        case broadcastStationSelectionPage(BroadcastStationSelectionPageModel)
    }
}
