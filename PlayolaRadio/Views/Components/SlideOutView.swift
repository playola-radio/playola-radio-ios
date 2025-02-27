import SwiftUI
import Sharing

@Observable
class SideMenuViewModel: ViewModel {
  var navigationCoordinator: NavigationCoordinator
  var stationPlayer: StationPlayer
  init(navigationCoordinator: NavigationCoordinator = .shared,
       stationPlayer: StationPlayer = .shared) {
    self.navigationCoordinator = navigationCoordinator
    self.stationPlayer = stationPlayer
  }

  var selectedSideMenuTab: SideMenuRowType {
    get {
      switch navigationCoordinator.activePath {
      case .about:
        return .about
      case .listen:
        return .listen
      case .signIn:
        return .listen
      }
    }
    set {
      switch newValue {
      case .about:
        self.navigationCoordinator.activePath = .about
      case .listen:
        self.navigationCoordinator.activePath = .listen
      }
    }
  }

  func rowTapped(row: SideMenuRowType) {
    self.selectedSideMenuTab = row
    self.navigationCoordinator.slideOutMenuIsShowing = false
  }

  func signOutTapped() {
    navigationCoordinator.activePath = .signIn
    StationPlayer.shared.stop()
    AuthService.shared.signOut()
    navigationCoordinator.slideOutMenuIsShowing = false
  }
}

enum SideMenuRowType: Int, CaseIterable, Equatable {
  case listen = 0
  case about

  var title: String{
    switch self {
    case .listen:
      return "Listen"
    case .about:
      return "About"
    }
  }

  var iconName: String{
    switch self {
    case .listen:
      return "headphones"
    case .about:
      return "info.circle"
    }
  }
}

struct SideMenuView: View {
  var model: SideMenuViewModel
  var body: some View {
    HStack {
      ZStack {

        VStack(alignment: .leading, spacing: 0) {
          ForEach(SideMenuRowType.allCases, id: \.self) { row in
            RowView(isSelected: model.selectedSideMenuTab == row,
                    imageName: row.iconName,
                    title: row.title) {
              model.rowTapped(row: row)
            }
          }
          Spacer()

          RowView(isSelected: false, imageName: "rectangle.portrait.and.arrow.right", title: "Sign Out") {
            model.signOutTapped()
          }
          .padding(.bottom, 30) // Adjust bottom padding as needed
        }
        .padding(.top, 100)
      }
      Spacer()
    }
    .background(.black)
  }

  func RowView(isSelected: Bool, imageName: String, title: String, hideDivider: Bool = false, action: @escaping (()->())) -> some View {
    Button {
      action()
    } label: {
      VStack(alignment: .leading) {
        HStack(spacing: 20) {
          Rectangle()
            .fill(isSelected ? Color.gray : .clear)
            .frame(width: 5)
          ZStack {
            Image(systemName: imageName)
              .resizable()
              .renderingMode(.template)
              .foregroundColor(isSelected ? .white : .gray)
              .frame(width: 26, height: 26)
          }
          .frame(width: 30, height: 30)
          Text(title)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(isSelected ? .white : .gray)
          Spacer()
        }
      }
    }
    .frame(height: 50)
    .background(
      LinearGradient(colors: [isSelected ? .white.opacity(0.5) : .clear, .clear],
                     startPoint: .leading,
                     endPoint: .trailing)
    )
  }
}
