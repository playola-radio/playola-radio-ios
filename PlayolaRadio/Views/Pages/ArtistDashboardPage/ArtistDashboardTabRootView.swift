//
//  ArtistDashboardTabRootView.swift
//  PlayolaRadio
//

import SwiftUI

struct ArtistDashboardTabRootView: View {
  let model: ArtistDashboardTabRootModel

  var body: some View {
    routedContent
      .task { await model.viewAppeared() }
  }

  @ViewBuilder
  private var routedContent: some View {
    switch model.route {
    case .loading:
      loadingView
    case .active(let activeModel):
      ArtistDashboardPageView(model: activeModel)
    case .setup(let setupModel):
      StationSetupPageView(model: setupModel)
    case .failed:
      failedView
    }
  }

  private var loadingView: some View {
    VStack {
      ProgressView()
        .tint(.white)
      Text(model.loadingText)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(.playolaGray)
        .padding(.top, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }

  private var failedView: some View {
    VStack(spacing: 8) {
      Text(model.failedTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 20))
        .foregroundColor(.white)
      Text(model.failedMessage)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(.playolaGray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }
}

#Preview {
  ArtistDashboardTabRootView(model: ArtistDashboardTabRootModel())
    .preferredColorScheme(.dark)
}
