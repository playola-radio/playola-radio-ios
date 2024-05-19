//
//  Models.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import IdentifiedCollections
import SwiftUI
import FRadioPlayer

struct SyncUp: Equatable, Identifiable, Codable {
  let id: UUID
  var attendees: IdentifiedArrayOf<Attendee> = []
  var duration: Duration = .seconds(60 * 5)
  var meetings: IdentifiedArrayOf<Meeting> = []
  var theme: Theme = .bubblegum
  var title = ""

  var durationPerAttendee: Duration {
    self.duration / self.attendees.count
  }
}

struct Attendee: Equatable, Identifiable, Codable {
  let id: UUID
  var name = ""
}

struct Meeting: Equatable, Identifiable, Codable {
  let id: UUID
  let date: Date
  var transcript: String
}

enum Theme: String, CaseIterable, Equatable, Identifiable, Codable {
  case bubblegum
  case buttercup
  case indigo
  case lavender
  case magenta
  case navy
  case orange
  case oxblood
  case periwinkle
  case poppy
  case purple
  case seafoam
  case sky
  case tan
  case teal
  case yellow

  var id: Self { self }

  var accentColor: Color {
    switch self {
    case .bubblegum, .buttercup, .lavender, .orange, .periwinkle, .poppy, .seafoam, .sky, .tan,
        .teal, .yellow:
      return .black
    case .indigo, .magenta, .navy, .oxblood, .purple:
      return .white
    }
  }

  var mainColor: Color { Color(self.rawValue) }

  var name: String { self.rawValue.capitalized }
}

extension SyncUp {
  static let mock = Self(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Esq"),
      Attendee(id: Attendee.ID(), name: "Blob III"),
      Attendee(id: Attendee.ID(), name: "Blob I"),
    ],
    duration: .seconds(60),
    meetings: [
      Meeting(
        id: Meeting.ID(),
        date: Date().addingTimeInterval(-60 * 60 * 24 * 7),
        transcript: """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
          dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. \
          Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
          mollit anim id est laborum.
          """
      )
    ],
    theme: .orange,
    title: "Design"
  )

  static let engineeringMock = Self(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: .seconds(60 * 10),
    theme: .periwinkle,
    title: "Engineering"
  )

  static let designMock = Self(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: .seconds(60 * 30),
    theme: .poppy,
    title: "Product"
  )
}

struct StationList: Decodable, Identifiable, Equatable, Sendable {
  static func == (lhs: StationList, rhs: StationList) -> Bool {
    return lhs.id == rhs.id
  }

  var id: String
  var title: String
  var stations: [RadioStation]
}

struct RadioStation: Decodable, Identifiable, Equatable, Sendable {
  static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
    return lhs.id == rhs.id
  }
  var id: String
  var name: String
  var streamURL: String
  var imageURL: String
  var desc: String
  var longDesc: String
  var type: StationType = .fm

  func processedImageURL() -> URL {
    if let url = URL(string: imageURL) { return url }
    return Bundle.main.url(forResource: "AppIcon", withExtension: "PNG")!
  }

  enum StationType: String, Decodable {
    case artist = "artist"
    case fm = "fm"
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

struct StationListResponse: Decodable {
  var stationLists: [StationList]
}
