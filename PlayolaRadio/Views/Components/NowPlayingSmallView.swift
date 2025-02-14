//
//  NowPlayingSmallView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/2/24.
//  Copyright © 2024 matthewfecher.com. All rights reserved.
//

import FRadioPlayer
import SwiftUI

@MainActor
struct NowPlayingSmallView: View {
    var artist: String?
    var title: String?
    var stationName: String?

    var body: some View {
        func nowPlayingTitle() -> String? {
            guard let artist, let title else {
                return nil
            }
            return "\(title) - \(artist)"
        }

        return VStack {
            HStack {
                VStack(alignment: .leading) {
                    if let title = nowPlayingTitle() {
                        Text(title)
                            .foregroundColor(Color(UIColor.lightText))
                            .font(Font(UIFont.preferredFont(forTextStyle: .callout)))
                    }

                    Text(stationName ?? "Choose a station above to begin...")
                        .foregroundColor(Color(UIColor.lightText))
                        .font(Font(UIFont.preferredFont(forTextStyle: .callout)))
                }.animation(.easeInOut(duration: 0.8), value: UUID())

                Spacer()

                if stationName != nil {
                    NowPlayingEqualiserBars()
                        .frame(width: 20, height: 20)
                        .padding()
                        .shadow(radius: 1)
                        .zIndex(1)
                        .transition(AnyTransition.scale.combined(with: .opacity))
                }
            }
        }
        .foregroundColor(.white)
        .background(Color.black.opacity(0.1))
    }
}

#Preview {
    ZStack {
        Color.black

        VStack {
            NowPlayingSmallView()
            NowPlayingSmallView(artist: "Bob Schneider", title: "The World Exploded into Love")
        }
    }
}
