//
//  Models.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import IdentifiedCollections
import SwiftUI
import FRadioPlayer

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



// MARK: Mocks
extension StationList {
  static var mocks: [StationList] {
    return [StationList(id: "in_development", title: "In Development", stations: [wcgStation]),
            StationList(id: "artist_stations", title: "Artists", stations: artistStations),
            StationList(id: "fm_stations", title: "FM Stations", stations: fmStations)]
  }
}

extension RadioStation {
  static var mock: RadioStation { return StationList.mocks[0].stations[0] }
}


private let wcgStation = RadioStation(
  id: "william_clark_green",
  name: "William Clark Green\'s",
  streamURL: "https://playoutonestreaming.com/proxy/billgreaseradio?mp=/stream",
  imageURL: "https://playola-static.s3.amazonaws.com/wcg_bgr_logo.jpeg",
  desc: "Bill Grease Radio",
  longDesc: "William Clark Green talks about his songs -- how they were written, the story " +
  "behind the recordings, and lots of little tidbits you won\'t hear anywhere else, all while " +
  "spinning his favorite songs and hanging out with some friends.",
  type: .artist)

private let artistStations: [RadioStation] = []

private let fmStations: [RadioStation] = [
  RadioStation(
    id: "koke_fm",
    name: "KOKE FM",
    streamURL: "https://arn.leanstream.co/KOKEFM-MP3",
    imageURL: "https://playola-static.s3.amazonaws.com/koke-fm-logo.jpeg",
    desc: "Austin, TX",
    longDesc: #"KOKE FM is an Austin, Texas based alternative country station. "Country Without Apology"."#
  ),
  RadioStation(
    id: "lakes_country",
    name: "Lakes Country 102.1",
    streamURL: "https://14833.live.streamtheworld.com/KEOKFMAAC.aac",
    imageURL: "https://playola-static.s3.amazonaws.com/KEOK_SMALL.jpeg",
    desc: "Tahlequah, OK",
    longDesc: "Lakes Country 102.1 provides today\'s best country (including Red Dirt & Local Music) along with community information, news & sports!"
  ),
  RadioStation(
    id: "kftx",
    name: "97.5 KFTX",
    streamURL: "https://ice7.securenetsystems.net/KFTX",
    imageURL: "https://playola-static.s3.amazonaws.com/kftx_logo.png",
    desc: "Corpus Christi, TX",
    longDesc: "KFTX.com is your 24 hour a day connection to yesterday\'s & today\'s REAL COUNTRY HITS and all your favorites!"
  ),
  RadioStation(
    id: "kgfy",
    name: "105.5 KGFY - Cowboy Country",
    streamURL: "https://ice24.securenetsystems.net/KGFY",
    imageURL: "https://playola-static.s3.amazonaws.com/kgfy_logo.png",
    desc: "Stillwater, OK",
    longDesc: "We play the hottest country music from Carrie Underwood, Keith Urban, Luke Bryan, Jason Aldean, Kenny Chesney to Miranda Lambert. Playing the best in Red Dirt from Aaron Watson, The Randy Rogers Band, The Turnpike Troubadours, Josh Abbott, and The Casey Donahew Band; plus so much more. Besides playing the best in country music, Cowboy Country 105.5 is also the voice of OSU Cowgirl Sports and Perkins Tryon High School sports. Stillwater knows country music. Hear it on KGFY Cowboy Country 105.5!"
  ),
  RadioStation(
    id: "lonestar_102_5",
    name: "Lonestar 102.5 - KHLB",
    streamURL: "https://ice42.securenetsystems.net/KHLB",
    imageURL: "https://playola-static.s3.amazonaws.com/KHLB_Logo.png",
    desc: "Mason, TX",
    longDesc: "Community-centered radio that offers dynamic, local news programming and country-music entertainment of the Texas Hill Country."
  ),
  RadioStation(
    id: "k95",
    name: "K-95.5 Continuous Country - KITX",
    streamURL: "https://prod-52-201-124-63.amperwave.net/wmpayne-kitxfmaac-hlsc2.m3u8",
    imageURL: "https://playola-static.s3.amazonaws.com/kitx_logo.jpeg",
    desc: "Paris, TX",
    longDesc: "The #1 radio station in Northeast Texas and Southeastern Oklahoma."
  ),
  RadioStation(
    id: "knes",
    name: "KNES Texas 99.1 FM",
    streamURL: "https://ice5.securenetsystems.net/KNES",
    imageURL: "https://playola-static.s3.amazonaws.com/knes_991_logo.png",
    desc: "Fairfield, TX",
    longDesc: "We\'re Taking Country Back"
  ),
  RadioStation(
    id: "krun",
    name: "KRUN 1400 AM",
    streamURL: "https://s29.myradiostream.com/12352/;?type=http",
    imageURL: "https://playola-static.s3.amazonaws.com/krun_1400am_logo.jpeg",
    desc: "Ballinger, TX",
    longDesc: "The #1 radio station in Northeast Texas and Southeastern Oklahoma."
  ),
  RadioStation(
    id: "KPUR",
    name: "95.7 KPUR FM",
    streamURL: "https://22963.live.streamtheworld.com/KPURFMAAC.aac",
    imageURL: "https://playola-static.s3.amazonaws.com/kpur_95_7_logo.png",
    desc: "Amarillo, TX",
    longDesc: "Amarillo\'s Country Music Station"
  ),
  RadioStation(
    id: "ksel",
    name: "KSEL Country 105.9 FM",
    streamURL: "https://streaming.live365.com/a44766",
    imageURL: "https://playola-static.s3.amazonaws.com/ksel_105_9_logo.png",
    desc: "Portales, NM",
    longDesc: "Your Kinda Country"
  )
]

