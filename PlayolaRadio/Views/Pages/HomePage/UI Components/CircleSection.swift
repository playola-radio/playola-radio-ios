//
//  CircleSection.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

extension View {
    func circleBackground() -> some View {
        self.background(
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
    }
}

struct CircleSection: View {
  var body: some View {
    VStack {
      HStack {
        Text("Welcome, Brian")
        .font(.custom("SpaceGrotesk-Light_Bold", size: 34))
        .fontWeight(.bold)
        .foregroundColor(.white)
        Spacer()
      }
      .onAppear { listInstalledFonts() }

      VStack {
        HStack {
          Spacer()
          Image("LogoMark") // Placeholder for your central logo
            .resizable()
            .scaledToFit()
            .frame(height: 80)
          Spacer()
        }
        .padding(.top, 20)
        .padding(.bottom, 20)

        Text("Discover music through independent artist made radio stations.")
          .foregroundColor(.white)
          .font(.custom("Inter-Regular", size: 20))
          .tracking(0.10)
          .lineSpacing(10)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)

      }
      .padding(.bottom, 50)
      .circleBackground()
      .clipped()

    }
    .padding(.top, 5)

    .clipped()
    .onAppear { listInstalledFonts() }
    .background(.black)
  }
}

struct CircleSection_Previews: PreviewProvider {
    static var previews: some View {
        CircleSection()
    }
}
