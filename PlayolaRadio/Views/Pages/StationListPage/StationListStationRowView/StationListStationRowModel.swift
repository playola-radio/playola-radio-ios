//
//  StationListStationRowModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

struct StationListStationRowModel {
  @Shared(.showSecretStations) var showSecretStations: Bool
  let item: APIStationItem

  var imageUrl: URL {
    return item.anyStation.processedImageURL()
  }

  var titleText: String {
    return item.anyStation.name
  }

  var subtitleText: String {
    let comingSoonText = "Coming Soon"
    if item.visibility == .comingSoon {
      if !showSecretStations {
        return comingSoonText
      }
      if let isActiveStation = item.station?.active,
        !isActiveStation
      {
        return comingSoonText
      }
    }
    return item.anyStation.stationName
  }

  var subtitleColor: Color {
    return subtitleText == "Coming Soon" ? Color.playolaRed : Color.white
  }

  init(item: APIStationItem) {
    self.item = item
  }
}

extension StationListStationRowModel: Equatable {
  static func == (lhs: StationListStationRowModel, rhs: StationListStationRowModel) -> Bool {
    return lhs.item.anyStation.id == rhs.item.anyStation.id
  }
}
