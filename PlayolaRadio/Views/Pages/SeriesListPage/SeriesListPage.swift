//
//  SeriesListPage.swift
//  PlayolaRadio
//

import SwiftUI

struct SeriesListPage: View {
  @Bindable var model: SeriesListPageModel

  var body: some View {
    VStack(spacing: 0) {
      // Page Title
      HStack {
        Text("Regularly Scheduled Shows")
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
          .tracking(0.12)
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 12)

      // Content
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(model.shows) { showWithAirings in
            SeriesCard(
              model: SeriesCardModel(
                showWithAirings: showWithAirings,
                subscriptionStatus: .autoSubscribed  // TODO: Wire up subscription status
              )
            )
          }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
      }
    }
    .background(Color(hex: "#130000"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .onAppear { Task { await model.viewAppeared() } }
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    SeriesListPage(model: SeriesListPageModel())
  }
  .preferredColorScheme(.dark)
}
