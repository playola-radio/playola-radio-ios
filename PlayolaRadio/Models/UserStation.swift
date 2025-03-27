//
//  UserStation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/5/25.
//

public struct UserStation: Codable, Sendable {
  public let id: String
  public let stationId: String
  public let userId: String
  public let role: String
}
