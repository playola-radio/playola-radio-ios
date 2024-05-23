//
//  NowPlayingDetailPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/22/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct StationDetailReducer {

  @ObservableState
  struct State: Equatable {
    var station: RadioStation
  }

  enum Action {
    case dismissButtonTapped
  }

  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .dismissButtonTapped:
        return .run { _ in
          await self.dismiss()
        }
      }
    }
  }
}

struct StationDetailPage: View {
  var store: StoreOf<StationDetailReducer>

  var body: some View {
    ZStack {
      Image("background")
        .resizable()
        .edgesIgnoringSafeArea(.all)

      VStack {
        HStack {
          AsyncImage(url: URL(string: store.station.imageURL)!) { image in
            image.resizable()
          } placeholder: {
            ProgressView().progressViewStyle(.circular)
          }
          .aspectRatio(contentMode: .fit)
          .frame(width: 68, height: 68)
          .padding(.trailing, 8)

          VStack(alignment: .leading) {
            Text(store.station.name)
              .font(.title3 )
            Text(store.station.desc)
          }

          Spacer()
        }
        .padding(.bottom, 20)

        Text(store.station.longDesc)
          .font(.subheadline)

        Spacer()

        Button(action: { store.send(.dismissButtonTapped) }) {
          Text("Okay")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .background(Color(hex: "#333335"))
      }
      .padding()
    }
    .foregroundStyle(.white)
  }
}

#Preview {
  NavigationStack {
    StationDetailPage(store: Store(initialState: StationDetailReducer.State(station: .mock), reducer: {
      StationDetailReducer()
    }))
  }

}
