//
//  Station.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/5/25.
//
import PlayolaPlayer
import Foundation

//public struct Station: Codable, Sendable {
//  public let id: String
//  public let name: String
//  public let userStation: UserStation?
//}
//
extension Station {
  public static var mock: Station {
    return Station(id: "12", name: "Something Cool", curatorName: "alsoCool", imageUrl: "", createdAt: Date.now, updatedAt: Date.now)
  }
}

//extension Station, Hashable, Equatable {
//
//}
