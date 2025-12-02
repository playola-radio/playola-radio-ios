//
//  Station+Mock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/2/25.
//

import PlayolaPlayer
import UIKit

extension Station {
  static func mockWith(
    id: String = "mock-station-id",
    name: String = "Mock Station",
    curatorName: String = "Mock Curator",
    imageUrl: URL? = nil,
    description: String = "A mock station for testing",
    active: Bool? = true,
    releaseDate: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> Station {
    Station(
      id: id,
      name: name,
      curatorName: curatorName,
      imageUrl: imageUrl,
      description: description,
      active: active,
      releaseDate: releaseDate,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
