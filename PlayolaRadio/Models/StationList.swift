//
//  StationList.swift
//  PlayolaRadio
//
//  Updated for Modern API Support
//

import FRadioPlayer
import IdentifiedCollections
import PlayolaPlayer
import SwiftUI

// Type-erased enum for station types that works with IdentifiedArray
enum AnyStation: Identifiable, Codable, Equatable {
  case playola(PlayolaPlayer.Station)
  case url(UrlStation)

  var id: String {
    switch self {
    case .playola(let station): return station.id
    case .url(let station): return station.id
    }
  }

  var name: String {
    switch self {
    case .playola(let station): return station.curatorName
    case .url(let station): return station.name
    }
  }

  var imageUrl: URL? {
    switch self {
    case .playola(let station): return station.imageUrl
    case .url(let station): return station.imageUrl
    }
  }

  var description: String {
    switch self {
    case .playola(let station): return station.description
    case .url(let station): return station.description
    }
  }

  var stationName: String {
    switch self {
    case .playola(let station): return station.name
    case .url(let station): return station.name
    }
  }

  var location: String? {
    switch self {
    case .playola: return nil
    case .url(let station): return station.location
    }
  }

  // Helper methods
  func processedImageURL() -> URL {
    if let url = imageUrl { return url }
    // swiftlint:disable:next force_unwrapping
    return Bundle.main.url(forResource: "AppIcon", withExtension: "PNG")!
  }

  var displayName: String {
    if let location = location {
      return "\(name) - \(location)"
    }
    return name
  }

  var isPlayolaStation: Bool {
    if case .playola = self { return true }
    return false
  }

  var isUrlStation: Bool {
    if case .url = self { return true }
    return false
  }

  // Image loading method for UI components
  func getImage(completion: @escaping (_ image: UIImage) -> Void) {
    switch self {
    case .playola(let station):
      if let imageUrl = station.imageUrl {
        UIImage.image(from: imageUrl) { image in
          // swiftlint:disable:next force_unwrapping
          completion(image ?? UIImage(named: "stationImage")!)
        }
      } else {
        // swiftlint:disable:next force_unwrapping
        let image = UIImage(named: "stationImage")!
        completion(image)
      }
    case .url(let station):
      station.getImage(completion: completion)
    }
  }
}

struct StationList: Codable, Identifiable, Equatable, Sendable {
  public enum KnownIDs: String {
    case artistList = "artist_list"
    case inDevelopmentList = "in_development_list"
    case fmStationsList = "fm_list"
  }

  static func == (lhs: StationList, rhs: StationList) -> Bool {
    lhs.id == rhs.id
  }

  // Modern API fields
  var id: String  // Now UUID instead of slug
  var name: String  // Was "title"
  var slug: String  // URL-friendly identifier
  var hidden: Bool
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date

  // Private - just for API decoding
  private var items: [APIStationItem]?

  // Computed properties for backward compatibility
  var title: String { name }

  // Return separate arrays of properly typed stations
  var playolaStations: [PlayolaPlayer.Station] {
    guard let items = items else { return [] }
    return
      items
      .sorted { $0.sortOrder < $1.sortOrder }
      .compactMap { $0.station }
  }

  var urlStations: [UrlStation] {
    guard let items = items else { return [] }
    return
      items
      .sorted { $0.sortOrder < $1.sortOrder }
      .compactMap { $0.urlStation }
  }

  // Combined array of AnyStation enum objects
  var stations: [AnyStation] {
    guard let items = items else { return [] }
    let sortedItems = items.sorted { $0.sortOrder < $1.sortOrder }
    var result: [AnyStation] = []

    for item in sortedItems {
      if let station = item.station {
        result.append(.playola(station))
      } else if let urlStation = item.urlStation {
        result.append(.url(urlStation))
      }
    }

    return result
  }

  init(
    id: String, name: String, slug: String, hidden: Bool = false, sortOrder: Int = 0,
    createdAt: Date, updatedAt: Date, items: [APIStationItem]? = nil
  ) {
    self.id = id
    self.name = name
    self.slug = slug
    self.hidden = hidden
    self.sortOrder = sortOrder
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.items = items
  }

  // Custom decoder to handle the API response format
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    slug = try container.decode(String.self, forKey: .slug)
    hidden = try container.decode(Bool.self, forKey: .hidden)
    sortOrder = try container.decode(Int.self, forKey: .sortOrder)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    items = try container.decodeIfPresent([APIStationItem].self, forKey: .items)
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, slug, hidden, sortOrder, createdAt, updatedAt, items
  }
}

struct APIStationItem: Codable {
  var sortOrder: Int
  var station: PlayolaPlayer.Station?
  var urlStation: UrlStation?
}

// MARK: Mocks - Updated for modern structure

extension StationList {
  static var mocks: IdentifiedArrayOf<StationList> {
    let now = Date()
    return IdentifiedArray(uniqueElements: [
      StationList(
        id: "in_development_list", name: "In Development", slug: "in_development_list",
        hidden: true, sortOrder: 0, createdAt: now, updatedAt: now,
        items: [APIStationItem(sortOrder: 0, station: mockPlayolaStation, urlStation: nil)]
      ),
      StationList(
        id: "artist_list", name: "Artists", slug: "artist-list",
        hidden: false, sortOrder: 1, createdAt: now, updatedAt: now,
        items: [APIStationItem(sortOrder: 0, station: nil, urlStation: mockUrlStation)]
      ),
      StationList(
        id: "fm_list", name: "FM Stations", slug: "fm_list",
        hidden: false, sortOrder: 2, createdAt: now, updatedAt: now,
        items: mockFMStationItems
      ),
    ])
  }
}

extension StationList {
  static var artistListSlug: String { return "artist-list" }
  static var inDevelopmentListId: String { return "in_development_list" }
  static var fmListId: String { return "fm_list" }
}

extension AnyStation {
  static var mock: AnyStation {
    StationList.mocks.first(where: { !$0.stations.isEmpty })?.stations.first ?? .url(mockUrlStation)
  }
}

// Mock data for testing
private let mockPlayolaStation = PlayolaPlayer.Station(
  id: "mock-playola-id",
  name: "Banned Radio",
  curatorName: "Bri Bagwell",
  imageUrl: "https://playola-static.s3.amazonaws.com/wcg_bgr_logo.jpeg",
  description: "Bri Bagwell talks about her songs -- how they were written, the story "
    + "behind the recordings, and lots of little tidbits you won't hear anywhere else, all while "
    + "spinning her favorite songs and hanging out with some friends.",
  active: true,
  createdAt: Date(),
  updatedAt: Date()
)

private let mockUrlStation = UrlStation(
  id: "mock-url-id",
  name: "Mock FM",
  streamUrl: "https://mock.stream.url",
  imageUrl: "https://mock.image.url",
  description: "Mock FM Station",
  website: nil,
  location: "Mock City, TX",
  active: true,
  createdAt: Date(),
  updatedAt: Date()
)

private let mockFMStationItems: [APIStationItem] = [
  APIStationItem(
    sortOrder: 0,
    station: nil,
    urlStation: UrlStation(
      id: "koke-fm-id",
      name: "KOKE FM",
      streamUrl: "https://arn.leanstream.co/KOKEFM-MP3",
      imageUrl: "https://playola-static.s3.amazonaws.com/koke-fm-logo.jpeg",
      description:
        "KOKE FM is an Austin, Texas based alternative country station. \"Country Without Apology\".",
      website: "https://kokefm.com/",
      location: "Austin, TX",
      active: true,
      createdAt: Date(),
      updatedAt: Date()
    )
  ),
  APIStationItem(
    sortOrder: 1,
    station: nil,
    urlStation: UrlStation(
      id: "lakes-country-id",
      name: "Lakes Country 102.1",
      streamUrl: "https://14833.live.streamtheworld.com/KEOKFMAAC.aac",
      imageUrl: "https://playola-static.s3.amazonaws.com/KEOK_SMALL.jpeg",
      description:
        "Lakes Country 102.1 provides today's best country (including Red Dirt & Local Music) "
        + "along with community information, news & sports!",
      website: nil,
      location: "Tahlequah, OK",
      active: true,
      createdAt: Date(),
      updatedAt: Date()
    )
  ),
  APIStationItem(
    sortOrder: 2,
    station: nil,
    urlStation: UrlStation(
      id: "kftx-id",
      name: "97.5 KFTX",
      streamUrl: "https://ice7.securenetsystems.net/KFTX",
      imageUrl: "https://playola-static.s3.amazonaws.com/kftx_logo.png",
      description: "KFTX.com is your 24 hour a day connection to yesterday's & today's "
        + "REAL COUNTRY HITS and all your favorites!",
      website: nil,
      location: "Corpus Christi, TX",
      active: true,
      createdAt: Date(),
      updatedAt: Date()
    )
  ),
]
