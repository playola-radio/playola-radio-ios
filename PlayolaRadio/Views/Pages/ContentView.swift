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
  @Shared(.slideOutViewModel) var slideOutViewModel
  @State var tempIsShowing: Bool = true
  @Bindable var navigationCoordinator: NavigationCoordinator = .init()

  @MainActor
  init() {
    navigationCoordinator = NavigationCoordinator.shared
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }

  func getBlurRadius() -> CGFloat {
    let progress =  (offset + gestureOffset) / (UIScreen.main.bounds.height * 0.50)
    return progress
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        NavigationStack(path: $navigationCoordinator.path) {
          StationListPage(model: StationListModel())
            .navigationDestination(for: NavigationCoordinator.Path.self) { path in
              switch path {
              case let .aboutPage(model):
                AboutPage(model: model)
              case let .stationListPage(model):
                StationListPage(model: model)
              case let .nowPlayingPage(model):
                NowPlayingView(model: model)
              }
            }
        }
        .accentColor(.white)
        .offset(x: max(self.offset + self.gestureOffset, 0))
        .animation(.interactiveSpring(
          response: 0.5,
          dampingFraction: 0.8,
          blendDuration: 0),
                   value: gestureOffset
        )
        .overlay(
          GeometryReader { _ in
            EmptyView()
          }
            .background(.black.opacity(0.6))
            .opacity(getBlurRadius())
            .animation(.interactiveSpring(
              response: 0.5,
              dampingFraction: 0.8,
              blendDuration: 0),
                       value: slideOutViewModel.isShowing)
            .onTapGesture {
              withAnimation { $slideOutViewModel.withLock { $0.isShowing.toggle() } }
            }
        )

        SideMenuView()
          .frame(width:  sideBarWidth)
          .animation(.interactiveSpring(
            response: 0.5,
            dampingFraction: 0.8,
            blendDuration: 0),
                     value: gestureOffset
          )
          .offset(x: -sideBarWidth)
          .offset(x: max(self.offset + self.gestureOffset, 0))
      }
      .gesture(
        DragGesture()
          .updating($gestureOffset, body: { value, out, _ in
            if value.translation.width > 0 && slideOutViewModel.isShowing {
              out = value.translation.width * 0.1
            } else {
              out = min(value.translation.width, sideBarWidth)
            }
          })
          .onEnded(onEnd(value:))
      )
      .onChange(of: slideOutViewModel.isShowing) { _, newValue in
        withAnimation {
          if newValue {
            offset = sideBarWidth
          } else {
            offset = 0
          }
        }
      }
    }
  }
  func onEnd(value: DragGesture.Value){
    let translation = value.translation.width
    if translation > 0 && translation > (sideBarWidth * 0.6) {
      $slideOutViewModel.withLock { $0.isShowing = true }
    } else if -translation > (sideBarWidth / 2) {
      $slideOutViewModel.withLock { $0.isShowing = false }
    } else {
      if offset == 0 || !slideOutViewModel.isShowing{
        return
      }
      $slideOutViewModel.withLock { $0.isShowing = true }
    }
  }
}


#Preview {
  NavigationStack {
    AppView()
  }
}
