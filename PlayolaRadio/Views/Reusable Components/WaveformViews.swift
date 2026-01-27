//
//  WaveformViews.swift
//  PlayolaRadio
//

import SwiftUI

// MARK: - Live Waveform View (during recording)

struct LiveWaveformView: View {
  let samples: [Float]
  private static let barCount = 60

  var body: some View {
    GeometryReader { geometry in
      let barWidth = (geometry.size.width - CGFloat(Self.barCount - 1) * 2) / CGFloat(Self.barCount)
      HStack(alignment: .center, spacing: 2) {
        let displaySamples = recentSamples()
        ForEach(0..<Self.barCount, id: \.self) { index in
          let height: CGFloat =
            index < displaySamples.count
            ? CGFloat(displaySamples[index]) * geometry.size.height
            : 4
          RoundedRectangle(cornerRadius: 1.5)
            .fill(index < displaySamples.count ? Color.playolaRed : Color(hex: "#4A4A4A"))
            .frame(width: barWidth, height: max(4, height))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func recentSamples() -> [Float] {
    guard !samples.isEmpty else { return [] }
    return Array(samples.suffix(Self.barCount))
  }
}

// MARK: - Waveform View (static, for review)

struct WaveformView: View {
  let samples: [Float]
  private static let barCount = 60

  init(samples: [Float]) {
    self.samples = samples
  }

  var body: some View {
    GeometryReader { geometry in
      let barWidth = (geometry.size.width - CGFloat(Self.barCount - 1) * 2) / CGFloat(Self.barCount)
      HStack(alignment: .center, spacing: 2) {
        let normalizedSamples = resampledSamples()
        ForEach(0..<Self.barCount, id: \.self) { barIndex in
          let height =
            barIndex < normalizedSamples.count
            ? CGFloat(normalizedSamples[barIndex]) * geometry.size.height
            : geometry.size.height * 0.2
          RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.playolaRed)
            .frame(width: barWidth, height: max(4, height))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func resampledSamples() -> [Float] {
    guard !samples.isEmpty else { return [] }
    let step = max(1, samples.count / Self.barCount)
    var result: [Float] = []
    for sampleIndex in stride(from: 0, to: samples.count, by: step) {
      let end = min(sampleIndex + step, samples.count)
      let avg = samples[sampleIndex..<end].reduce(0, +) / Float(end - sampleIndex)
      result.append(avg)
    }
    return Array(result.prefix(Self.barCount))
  }
}
