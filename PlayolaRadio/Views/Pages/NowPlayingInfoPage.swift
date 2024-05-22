//
//  NowPlayingDetailPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/22/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NowPlayingDetailReducer {
  
  @ObservableState
  struct State {
    var station: RadioStation
  }
  
  enum Action {
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      return .none
    }
  }
}

struct NowPlayingDetailPage: View {
  var store: StoreOf<NowPlayingDetailReducer>
  
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
        
        Button(action: {}) {
          Text("Okay")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .background(Color(hex: "#333335"))
      }
      .padding()
    }
  }
}

#Preview {
  NavigationStack {
    NowPlayingDetailPage(store: Store(initialState: NowPlayingDetailReducer.State(station: .mock), reducer: {
      NowPlayingDetailReducer()
    }))
    .foregroundStyle(.white)
  }
  
}
