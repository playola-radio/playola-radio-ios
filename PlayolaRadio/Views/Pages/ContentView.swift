//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import SwiftUI
import Sharing

@MainActor
class ViewModel: Hashable {
  nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
    ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

@MainActor
struct AppView: View {
  var sideBarWidth = UIScreen.main.bounds.size.width * 0.5
  @State var offset: CGFloat = 0
  @GestureState var gestureOffset: CGFloat = 0
  @Bindable var navigationCoordinator: NavigationCoordinator
  @Shared(.auth) var auth

  // Add animation configuration
  private let menuTransitionAnimation = Animation.interactiveSpring(
    response: 0.5,
    dampingFraction: 0.8,
    blendDuration: 0
  )

  @MainActor
  init(navigationCoordinator: NavigationCoordinator = .shared) {
    self.navigationCoordinator = navigationCoordinator
    navigationCoordinator.activePath = auth.isLoggedIn ? .listen : .signIn
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }

  func getBlurRadius() -> CGFloat {
    let progress = (offset + gestureOffset) / (UIScreen.main.bounds.height * 0.50)
    return progress
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Color.black.edgesIgnoringSafeArea(.all)

        
        NavigationStack(path: $navigationCoordinator.path) {
          Group {
            switch navigationCoordinator.activePath {
            case .about:
              AboutPage(model: AboutPageModel())
            case .listen:
              StationListPage(model: StationListModel())
                .transition(.opacity) // Add smooth transition between views
            case .signIn:
              SignInPage(model: SignInPageModel())
            case .broadcast:
              BroadcastBasePage(model: BroadcastBaseModel())
            }
          }
          .navigationDestination(for: NavigationCoordinator.Path.self) { path in
            switch path {
            case let .aboutPage(model):
              AboutPage(model: model)
            case let .stationListPage(model):
              StationListPage(model: model)
            case let .nowPlayingPage(model):
              NowPlayingView(model: model)
            case let .signInPage(model):
              SignInPage(model: model)
            case let .broadcast(model: model):
              BroadcastBasePage(model: model)
            }
          }
        }
        .accentColor(.white)
        .offset(x: max(self.offset + self.gestureOffset, 0))
        // Apply consistent animation
        .animation(menuTransitionAnimation, value: gestureOffset)
        .animation(menuTransitionAnimation, value: offset)
        .overlay(
          GeometryReader { _ in
            EmptyView()
          }
          .background(.black.opacity(0.6))
          .opacity(getBlurRadius())
          .animation(menuTransitionAnimation, value: navigationCoordinator.slideOutMenuIsShowing)
          .onTapGesture {
            withAnimation(menuTransitionAnimation) {
              navigationCoordinator.slideOutMenuIsShowing.toggle()
            }
          }
        )

        SideMenuView(model: SideMenuViewModel())
          .frame(width: sideBarWidth)
          // Make the animation consistent
          .animation(menuTransitionAnimation, value: gestureOffset)
          .offset(x: -sideBarWidth)
          .offset(x: max(self.offset + self.gestureOffset, 0))
      }
      .gesture(
        DragGesture()
          .updating($gestureOffset, body: { value, out, _ in
            if value.translation.width > 0 && navigationCoordinator.slideOutMenuIsShowing {
              out = value.translation.width * 0.1
            } else {
              out = min(value.translation.width, sideBarWidth)
            }
          })
          .onEnded(onEnd(value:))
      )
      .onChange(of: navigationCoordinator.slideOutMenuIsShowing) { _, newValue in
        withAnimation(menuTransitionAnimation) {
          if newValue {
            offset = sideBarWidth
          } else {
            offset = 0
          }
        }
      }
    }
  }

  func onEnd(value: DragGesture.Value) {
    let translation = value.translation.width

    withAnimation(menuTransitionAnimation) {
      if translation > 0 && translation > (sideBarWidth * 0.6) {
        navigationCoordinator.slideOutMenuIsShowing = true
      } else if -translation > (sideBarWidth / 2) {
        navigationCoordinator.slideOutMenuIsShowing = false
      } else {
        if offset == 0 || !navigationCoordinator.slideOutMenuIsShowing {
          return
        }
        navigationCoordinator.slideOutMenuIsShowing = true
      }
    }
  }
}

#Preview {
  NavigationStack {
    AppView()
  }
}
