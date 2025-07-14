//
//  CircleSection.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

struct HomeIntroSection: View {
  var onIconTapped10Times: () -> Void = {}
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Content with circles
      VStack(spacing: 20) {
        Image("LogoMark")
          .resizable()
          .scaledToFit()
          .frame(width: 76, height: 98)
          .padding(.bottom, 32)
          .onTapGesture(count: 10,
                        perform: onIconTapped10Times)
        
        Text("Discover music through independent artist made radio stations.")
          .foregroundColor(.white)
          .font(.custom("Inter-Regular", size: 20))
          .tracking(0.10)
          .lineSpacing(10)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }
      .padding(.top, 40)
      .padding(.bottom, 80)
      .frame(maxWidth: .infinity)
      .clipped()
    }
    .background(Color.clear)
  }
}

struct CircleSection_Previews: PreviewProvider {
  static var previews: some View {
    HomeIntroSection()
      .padding(.horizontal, 24)
      .background(Color.black)
  }
}
