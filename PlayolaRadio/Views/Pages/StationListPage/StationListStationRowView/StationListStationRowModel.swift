//
//  StationListStationRowModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import Foundation

struct StationListStationRowModel: Equatable {
  let imageUrl: URL
  let titleText: String
  let subtitleText: String

  init(item: APIStationItem) {
    if let station = item.anyStation {
      imageUrl = station.imageUrl ?? station.processedImageURL()
      titleText = station.name
      subtitleText = station.stationName
    } else {
      let fallback = AnyStation.mock
      imageUrl = fallback.imageUrl ?? fallback.processedImageURL()
      titleText = fallback.name
      subtitleText = fallback.stationName
    }
  }

  init(imageUrl: URL, titleText: String, subtitleText: String) {
    self.imageUrl = imageUrl
    self.titleText = titleText
    self.subtitleText = subtitleText
  }
}
