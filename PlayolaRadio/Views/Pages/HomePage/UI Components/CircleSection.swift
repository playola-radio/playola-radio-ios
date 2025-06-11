//
//  CircleSection.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

struct HomeIntroSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Welcome text - flush with top, minimal padding
            Text("Welcome, Brian")
                .font(.custom("SpaceGrotesk-Light_Bold", size: 34))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black)

            // Content with circles
            VStack(spacing: 20) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)

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
        .onAppear { listInstalledFonts() }
    }
}

struct CircleSection_Previews: PreviewProvider {
    static var previews: some View {
      HomeIntroSection()
        .background(Color.black)
    }
}
