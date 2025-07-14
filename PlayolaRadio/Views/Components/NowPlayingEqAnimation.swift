//
//  NowPlayingEqAnimation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/2/24.
//  Copyright 2024 matthewfecher.com. All rights reserved.

import SwiftUI

@MainActor
struct NowPlayingEqDemoView: View {
  @State private var nowPlayingIndex = -1
  
  var body: some View {
    let numItems = 20
    let opacityDeltaPerItem = 1 / Double(numItems)
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
      ForEach(0 ..< numItems, id: \.self) { index in
        let isNowPlaying = index == nowPlayingIndex
        Button {
          withAnimation(.easeInOut) {
            if isNowPlaying {
              nowPlayingIndex = -1
            } else {
              nowPlayingIndex = index
            }
          }
        } label: {
          ZStack(alignment: .bottomLeading) {
            Rectangle()
              .fill(Color.blue.opacity(
                opacityDeltaPerItem + opacityDeltaPerItem * Double(index)
              ))
              .frame(height: 120)
            if isNowPlaying {
              NowPlayingEqualiserBars()
                .frame(width: 20, height: 20)
                .padding()
                .shadow(radius: 1)
                .zIndex(1)
                .transition(AnyTransition.scale.combined(with: .opacity))
            }
          }
        }
      }
    }
  }
}

public struct NowPlayingEqualiserBars: View {
  var numBars = 5
  var spacerWidthRatio: CGFloat = 0.2
  
  private var barWidthScaleFactor: CGFloat {
    1 / (CGFloat(numBars) + CGFloat(numBars - 1) * spacerWidthRatio)
  }
  
  @State private var animating = false
  
  public var body: some View {
    GeometryReader { (geo: GeometryProxy) in
      let barWidth = geo.size.width * barWidthScaleFactor
      let spacerWidth = barWidth * spacerWidthRatio
      HStack(spacing: spacerWidth) {
        ForEach(0 ..< numBars, id: \.self) { _ in
          Bar(
            minHeightFraction: 0.1,
            maxHeightFraction: 1,
            completion: animating ? 1 : 0
          )
          .fill(Color.white)
          .frame(width: barWidth)
          .animation(createAnimation(), value: animating)
        }
      }
    }
    .onAppear {
      DispatchQueue.main.async {
        animating = true
      }
    }
  }
  
  private func createAnimation() -> Animation {
    Animation
      .easeInOut(duration: 0.8 + Double.random(in: -0.3 ... 0.3))
      .repeatForever(autoreverses: true)
      .delay(Double.random(in: 0 ... 0.75))
  }
}

private struct Bar: Shape {
  private let minHeightFraction: CGFloat
  private let maxHeightFraction: CGFloat
  var animatableData: CGFloat
  
  init(minHeightFraction: CGFloat, maxHeightFraction: CGFloat, completion: CGFloat) {
    self.minHeightFraction = minHeightFraction
    self.maxHeightFraction = maxHeightFraction
    animatableData = completion
  }
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    
    let heightFractionDelta = maxHeightFraction - minHeightFraction
    let heightFraction = minHeightFraction + heightFractionDelta * animatableData
    
    let rectHeight = rect.height * heightFraction
    
    let rectOrigin = CGPoint(x: rect.minX, y: rect.maxY - rectHeight)
    let rectSize = CGSize(width: rect.width, height: rectHeight)
    
    let barRect = CGRect(origin: rectOrigin, size: rectSize)
    
    path.addRect(barRect)
    
    return path
  }
}

struct NowPlayingEqDemoView_Previews: PreviewProvider {
  struct DemoHarness: View {
    var body: some View {
      NowPlayingEqDemoView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(.white)
        .background(Color(white: 0.1))
        .ignoresSafeArea()
    }
  }
  
  static var previews: some View {
    DemoHarness()
      .previewDevice("iPhone 12 Pro Max")
      .previewDisplayName("iPhone 12 Pro Max")
  }
}
