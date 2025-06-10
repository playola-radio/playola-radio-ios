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
      .padding(.bottom, 16)

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
    .padding(.top, 5)
    .padding(.bottom, 50)
    .padding(.horizontal, 32)
    .background(
      ZStack {
        Color.black
        ZStack() {
            Ellipse()
                .foregroundColor(.clear)
                .frame(width: 171, height: 171)
                .overlay(
                    Ellipse()
                        .inset(by: 6)
                        .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                )
                .offset(x: 0.41, y: 0.41)
            Ellipse()
                .foregroundColor(.clear)
                .frame(width: 270.13, height: 270.13)
                .overlay(
                    Ellipse()
                        .inset(by: 6)
                        .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                )
                .offset(x: 0.14, y: 0.14)
            Ellipse()
                .foregroundColor(.clear)
                .frame(width: 366.78, height: 366.78)
                .overlay(
                    Ellipse()
                        .inset(by: 6)
                        .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                )
                .offset(x: -0.42, y: -0.42)
            Ellipse()
                .foregroundColor(.clear)
                .frame(width: 456, height: 456)
                .overlay(
                    Ellipse()
                        .inset(by: 6)
                        .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                )
                .offset(x: 0, y: 0)
        }
        .frame(width: 456, height: 200)
      }
    )
    .clipped()
    .onAppear { listInstalledFonts() }
  }

}

struct CircleSection_Previews: PreviewProvider {
    static var previews: some View {
        CircleSection()
    }
}
