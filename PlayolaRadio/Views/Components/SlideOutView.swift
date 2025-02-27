import SwiftUI
import Sharing

@Observable
class SlideOutViewModel: ViewModel {
    var isShowing = false
  var selectedSideMenuTab = 0
}

enum SideMenuRowType: Int, CaseIterable{
    case listen = 0
    case settings

    var title: String{
        switch self {
        case .listen:
            return "Listen"
        case .settings:
            return "About"
        }
    }

    var iconName: String{
        switch self {
        case .listen:
            return "headphones"
        case .settings:
          return "info.circle"
        }
    }
}

struct SideMenuView: View {
  @Shared(.slideOutViewModel) var slideOutViewModel

  var body: some View {
    HStack {
      ZStack {

        VStack(alignment: .leading, spacing: 0) {
          ForEach(SideMenuRowType.allCases, id: \.self) { row in
            RowView(isSelected: slideOutViewModel.selectedSideMenuTab == row.rawValue, imageName: row.iconName, title: row.title) {
              $slideOutViewModel.withLock {
                $0.selectedSideMenuTab = row.rawValue
                $0.isShowing.toggle()
              }
            }
          }
          Spacer()

          RowView(isSelected: false, imageName: "rectangle.portrait.and.arrow.right", title: "Sign Out") {
            $slideOutViewModel.withLock {
              $0.isShowing.toggle()
            }
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
