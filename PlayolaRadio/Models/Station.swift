//
//  Station.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/5/25.
//

struct Station: Codable {
  let id: String
  let name: String
  let userStation: UserStation?
}

extension Station {
  static var mock: Station {
    return Station(id: "12", name: "Somthing Cool", userStation:
      UserStation(id: "1", stationId: "1", userId: "userId", role: "owner")
    )
  }
}
