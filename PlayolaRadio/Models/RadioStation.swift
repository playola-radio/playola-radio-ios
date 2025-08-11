import FRadioPlayer
//
//  RadioStation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import Foundation
import UIKit

public struct RadioStation: Codable, Identifiable, Equatable, Sendable {
  public static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
    lhs.id == rhs.id
  }

  public var id: String
  public var name: String
  public var playolaID: String?
  public var streamURL: String?
  public var imageURL: String
  public var desc: String
  public var longDesc: String
  public var type: StationType = .fm

  public func processedImageURL() -> URL {
    if let url = URL(string: imageURL) { return url }
    return Bundle.main.url(forResource: "AppIcon", withExtension: "PNG")!
  }

  public enum StationType: String, Codable {
    case artist
    case fm
    case playola
  }

  public var longName: String {
    type == .artist
      ? "\(name) \(desc)"
      : name
  }
}

#if canImport(UIKit)
  extension RadioStation {
    public func getImage(completion: @escaping (_ image: UIImage) -> Void) {
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
#endif

extension RadioStation {
  public var trackName: String {
    FRadioPlayer.shared.currentMetadata?.trackName ?? name
  }

  public var artistName: String {
    FRadioPlayer.shared.currentMetadata?.artistName ?? desc
  }
}
