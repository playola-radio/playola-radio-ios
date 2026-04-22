import FRadioPlayer
//
//  RadioStation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import Foundation
import UIKit

struct RadioStation: Codable, Identifiable, Equatable, Sendable {
  static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
    lhs.id == rhs.id
  }

  var id: String
  var name: String
  var playolaID: String?
  var streamURL: String?
  var imageURL: String
  var desc: String
  var longDesc: String
  var type: StationType = .fm

  func processedImageURL() -> URL {
    if let url = URL(string: imageURL) { return url }
    // swiftlint:disable:next force_unwrapping
    return Bundle.main.url(forResource: "AppIcon", withExtension: "PNG")!
  }

  enum StationType: String, Codable {
    case artist
    case fm
    case playola
  }

  var longName: String {
    type == .artist
      ? "\(name) \(desc)"
      : name
  }
}

extension RadioStation {
  func getImage() async -> UIImage {
    if imageURL.range(of: "http") != nil, let url = URL(string: imageURL) {
      let image = await UIImage.image(from: url)
      // swiftlint:disable:next force_unwrapping
      return image ?? UIImage(named: "stationImage")!
    }
    // swiftlint:disable:next force_unwrapping
    return UIImage(named: imageURL) ?? UIImage(named: "stationImage")!
  }
}

extension RadioStation {
  var trackName: String {
    FRadioPlayer.shared.currentMetadata?.trackName ?? name
  }

  var artistName: String {
    FRadioPlayer.shared.currentMetadata?.artistName ?? desc
  }
}
