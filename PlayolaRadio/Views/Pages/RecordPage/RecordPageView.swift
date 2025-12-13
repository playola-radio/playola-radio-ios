//
//  RecordPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import SwiftUI

struct RecordPageView: View {
  @Bindable var model: RecordPageModel

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack {
        Spacer()
        Text("Record VoiceTrack")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 24))
          .foregroundColor(.white)
        Text("Coming Soon")
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.playolaGray)
          .padding(.top, 8)
        Spacer()
      }
    }
    .navigationTitle("Record")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .task {
      await model.viewAppeared()
    }
  }
}

#Preview {
  NavigationStack {
    RecordPageView(model: RecordPageModel())
  }
  .preferredColorScheme(.dark)
}
