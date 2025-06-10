//
//  ScheduleCellView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

import Combine
import SwiftUI
import PlayolaPlayer

@MainActor
@Observable
class ScheduleCellViewModel: ViewModel {
  let spin: Spin
  let isBeingScheduled: Bool = false

  public init(spin: Spin) {
    self.spin = spin
  }
}

struct ScheduleCellView: View {
  var model: ScheduleCellViewModel
  var playPreview: (() -> Void)? = nil

  @State var voiceTrackPreviewIsLoading: Bool = false
  @State var voiceTrackPreviewLoadingProgress: Double = 0.7
  @State var voiceTrackPreviewButtonEnabled: Bool = true

  var body: some View {
    HStack {
      switch model.spin.audioBlock?.type {
      case "commercialblock":
        Image("greedyFace")
          .resizable()
          .frame(width: 45.0, height: 33.0)
          .padding(.zero)
      case "voicetrack":
        Image("voicetrackAlbumArtwork")
          .resizable()
          .frame(width: 45.0, height: 45.0)
          .padding(.zero)
      default:
        AsyncImage(url: model.spin.audioBlock?.imageUrl) { image in
          image
            .resizable()
            .frame(width: 45.0, height: 45.0)
            .padding(.zero)
        } placeholder: {
          Image("emptyAlbumWithOverlay")
            .resizable()
            .frame(width: 45.0, height: 45.0)
            .padding(.zero)
        }
      }

      Spacer()
        .frame(width: 10)

      VStack {
        HStack {
          Text(model.spin.audioBlock?.title ?? "")
            .foregroundColor(.white)
            .font(.custom("OpenSans-Bold", size: 12.0))
            .multilineTextAlignment(.leading)
          Spacer()
        }
        if model.spin.audioBlock?.type != "voicetrack" && model.spin.audioBlock?.type != "commercial" {
          HStack {
            Text(model.spin.audioBlock?.artist ?? "")
              .foregroundColor(.playolaGray)
              .font(.custom("OpenSans-Semibold", size: 10.0))
              .multilineTextAlignment(.leading)
            Spacer()
          }
        }
      }
      Spacer()

      if model.spin.audioBlock?.type == "voicetrack" {
        if self.voiceTrackPreviewIsLoading {
          CircularProgressView(progress: voiceTrackPreviewLoadingProgress)
            .padding(0)
            .foregroundColor(.playolaRed)

            .frame(width: 20, height: 20)
            .animation(Animation.linear, value: 25) // << here !!
            .aspectRatio(contentMode: .fit)
            .padding(.trailing, 30)
        } else {
          Button {
            self.playPreview?()

          } label: {
            Image("myScheduleCellPlayEnabled")
              .resizable()
              .frame(width: 20, height: 20)
              .aspectRatio(contentMode: .fit)
              .padding(.trailing, 30)
          }
        }
      }

      ZStack {
        if model.isBeingScheduled {
          ProgressView()
            .progressViewStyle(.circular)
            .foregroundColor(.white)
            .frame(width: 23, height: 23)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 7))
        } else {
          Text("at \(model.spin.airtime.toBeautifulStringWithSecs())")
            .font(.custom("Roboto-Regular", size: 11))
            .foregroundColor(Color.playolaGray)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
        }
      }

      Image("myScheduleCellHandle")
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
    }
    .edgesIgnoringSafeArea(.all)
    .background(model.spin.audioBlock?.type == "commercialblock" ? Color.black : Color(hex: "333333"))
    .padding(.zero)
    .listRowInsets(EdgeInsets())
    .frame(height: model.spin.audioBlock?.type == "commercialblock" ? 33 : 45)
    .listRowSeparator(.hidden)
  }
}

struct ScheduleCellView_Previews: PreviewProvider {
  static var previews: some View {
    ScheduleCellView(model: ScheduleCellViewModel(spin: .mock))
  }
}

struct PieShape: Shape {
  var progress: Double = 0.0
  private let startAngle: Double = (Double.pi) * 1.5
  private var endAngle: Double {
    return startAngle + Double.pi * 2 * progress
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let arcCenter = CGPoint(x: rect.size.width / 2, y: rect.size.width / 2)
    let radius = rect.size.width / 2
    path.move(to: arcCenter)
    path.addArc(center: arcCenter, radius: radius, startAngle: Angle(radians: startAngle), endAngle: Angle(radians: endAngle), clockwise: false)
    path.closeSubpath()
    return path
  }
}

struct CircularProgressView: View {
  var progress: Double

  var body: some View {
    let progressText = String(format: "%.0f%%", progress * 100)
    let purpleAngularGradient = AngularGradient(
      gradient: Gradient(colors: [
        .white,
        .white,
      ]),
      center: .center,
      startAngle: .degrees(0),
      endAngle: .degrees(360.0 * progress)
    )

    ZStack {
      Circle()
        .stroke(Color(.systemGray4), lineWidth: 2)
      Circle()
        .trim(from: 0, to: CGFloat(self.progress))
        .stroke(
          purpleAngularGradient,
          style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .rotationEffect(Angle(degrees: -90))
        .overlay(
          Text(progressText)
            .font(.system(size: 6, weight: .bold, design: .rounded))
            .foregroundColor(Color(.white))
        )
    }
    .frame(width: 20, height: 20)
    .padding()
  }
}
