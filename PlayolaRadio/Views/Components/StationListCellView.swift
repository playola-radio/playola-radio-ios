//
//  StationListCellView.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/6/24.
//

import SwiftUI

struct StationListCellView: View {
  var station: RadioStation
  
  var body: some View {
    HStack {
      AsyncImage(url: URL(string: station.imageURL)!) { image in
        image.resizable()
      } placeholder: {
        ProgressView().progressViewStyle(.circular)
      }
      .aspectRatio(contentMode: .fit)
      .frame(width: 68, height: 68)
      .background(.white.opacity(0.5))
      .padding(.trailing, 8)
      VStack {
        Text(station.name)
          .font(.title3)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 6)
        
        Text(station.desc)
          .font(.footnote)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.clear)
      }
      Spacer()
    }
    .frame(height: 90)
  }
}

#Preview {
  List {
    StationListCellView(station: RadioStation.mock)
      .listRowBackground(Color.black)
  }
  .background(.black)
  .foregroundStyle(.white)
}
