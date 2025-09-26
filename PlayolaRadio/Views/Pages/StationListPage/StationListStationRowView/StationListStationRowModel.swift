//
//  StationListStationRowModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import Foundation
import Sharing

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
    if item.visibility == .comingSoon && !showSecretStations {
      return "Coming Soon"
    }
    return item.anyStation.stationName
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
