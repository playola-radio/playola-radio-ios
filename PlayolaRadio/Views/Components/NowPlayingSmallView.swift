//
//  NowPlayingSmallView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/2/24.
//  Copyright © 2024 matthewfecher.com. All rights reserved.
//

import SwiftUI
import FRadioPlayer

struct NowPlayingSmallView: View {
    var metadata: FRadioPlayer.Metadata?
    var stationName: String?
    
    var body: some View {
        func nowPlayingTitle() -> String? {
            guard let trackName = metadata?.trackName, let artistName = metadata?.artistName else {
                return nil
            }
            return "\(trackName) - \(artistName)"
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
          NowPlayingSmallView(metadata: FRadioPlayer.Metadata(artistName: "Bob Schneider", trackName: "The World Exploded into Love", rawValue: nil, groups: []))
      }
  }
}
