//
//  CircleSection.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

struct CircleSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Welcome, Brian")
        .font(.custom("SpaceGrotesk-Light_Bold", size: 24))
        .fontWeight(.bold)
        .foregroundColor(.white)
        Spacer()
      }
      HStack {
        Spacer()
        Image("LogoMark") // Placeholder for your central logo
          .resizable()
          .scaledToFit()
          .frame(height: 80)
        Spacer()
      }


      Text("Discover music through independent artist made radio stations.")
        .foregroundColor(.white)
        .font(.body)
        .lineLimit(nil)
    }
    .padding()
    .background(
      RadialGradient(gradient: Gradient(colors: [.black, .gray]), center: .center, startRadius: 5, endRadius: 500)
    )
    .onAppear { listInstalledFonts() }
  }

}

struct CircleSection_Previews: PreviewProvider {
    static var previews: some View {
        CircleSection()
    }
}
