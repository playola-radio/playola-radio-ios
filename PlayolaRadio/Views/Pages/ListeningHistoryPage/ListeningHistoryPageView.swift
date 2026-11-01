import SwiftUI

struct ListeningHistoryPageView: View {
  @Bindable var model: ListeningHistoryPageModel

  var body: some View {
    Text(model.navigationTitle)
      .task { await model.detailAppeared() }
  }
}
