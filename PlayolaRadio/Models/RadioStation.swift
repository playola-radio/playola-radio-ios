//
//  RadioStation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import Foundation
import UIKit
import FRadioPlayer

struct RadioStation: Codable, Identifiable, Equatable, Sendable {
  static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
    return lhs.id == rhs.id
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
    return Bundle.main.url(forResource: "AppIcon", withExtension: "PNG")!
  }

  enum StationType: String, Codable {
    case artist = "artist"
    case fm = "fm"
    case playola = "playola"
  }

  var longName: String {
    type == .artist
    ? "\(name) \(desc)"
    : name
  }
}

extension RadioStation {
  func getImage(completion: @escaping (_ image: UIImage) -> Void) {

    if imageURL.range(of: "http") != nil, let url = URL(string: imageURL) {
      // load current station image from network
      UIImage.image(from: url) { image in
        completion(image ?? #imageLiteral(resourceName: "stationImage"))
      }
    } else {
      // load local station image
      let image = UIImage(named: imageURL) ?? #imageLiteral(resourceName: "stationImage")
      completion(image)
    }
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
