//
//  StationList.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import FRadioPlayer
import IdentifiedCollections
import SwiftUI

struct StationList: Codable, Identifiable, Equatable, Sendable {
    public enum KnownIDs: String {
        case artistList = "artist_list"
        case inDevelopmentList = "in_development_list"
        case fmStationsList = "fm_list"
    }

    static func == (lhs: StationList, rhs: StationList) -> Bool {
        lhs.id == rhs.id
    }

    var id: String
    var title: String
    var hidden: Bool = false
    var stations: [RadioStation]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        hidden = (try? container.decode(Bool.self, forKey: .hidden)) ?? false
        stations = try container.decode([RadioStation].self, forKey: .stations)
    }

    init(id: String, title: String, hidden: Bool = false, stations: [RadioStation]) {
        self.id = id
        self.title = title
        self.hidden = hidden
        self.stations = stations
    }
}

struct StationListResponse: Decodable {
    var stationLists: [StationList]
}

// MARK: Mocks

extension StationList {
    static var mocks: IdentifiedArrayOf<StationList> {
        IdentifiedArray(uniqueElements:
            [StationList(id: "in_development_list", title: "In Development", stations: [briStation]),
             StationList(id: "artist_list", title: "Artists", stations: artistStations),
             StationList(id: "fm_list", title: "FM Stations", stations: fmStations)])
    }
}

extension StationList {
  static var artistListId: String { return "artist_list" }
  static var inDevelopmentListId: String { return "in_development_list" }
  static var fmListId: String { return "fm_list" }
}

extension RadioStation {
    static var mock: RadioStation { StationList.mocks[0].stations[0] }
}

private let briStation = RadioStation(
    id: "bri_bagwell",
    name: "Bri Bagwell\'s",
    streamURL: "https://playoutonestreaming.com/proxy/billgreaseradio?mp=/stream",
    imageURL: "https://playola-static.s3.amazonaws.com/wcg_bgr_logo.jpeg",
    desc: "Banned Radio",
    longDesc: "Bri Bagwell talks about her songs -- how they were written, the story " +
        "behind the recordings, and lots of little tidbits you won\'t hear anywhere else, all while " +
        "spinning his favorite songs and hanging out with some friends.",
    type: .artist
)

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
        longDesc: "We play the hottest country music from Carrie Underwood, Keith Urban, Luke Bryan, Jason Aldean, " +
            "Kenny Chesney to Miranda Lambert. Playing the best in Red Dirt from Aaron Watson, The Randy Rogers Band, " +
            "The Turnpike Troubadours, Josh Abbott, and The Casey Donahew Band; plus so much more. Besides playing the " +
            "best in country music, Cowboy Country 105.5 is also the voice of OSU Cowgirl Sports and Perkins Tryon " +
            "High School sports. Stillwater knows country music. Hear it on KGFY Cowboy Country 105.5!"
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