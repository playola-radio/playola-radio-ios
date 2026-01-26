//
//  ListenerQuestionAiring.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer

/// A scheduled airing of a listener's answered Q&A
struct ListenerQuestionAiring: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let listenerQuestionId: String
  let stationId: String
  let airtime: Date
  let station: Station?
  let listenerQuestion: ListenerQuestion?
  let createdAt: Date?
  let updatedAt: Date?
}

// MARK: - Mock

extension ListenerQuestionAiring {
  static var mock: ListenerQuestionAiring {
    .mockWith()
  }

  static func mockWith(
    id: String = "mock-airing-id",
    listenerQuestionId: String = "mock-question-id",
    stationId: String = "mock-station-id",
    airtime: Date = Date().addingTimeInterval(2 * 24 * 60 * 60),
    station: Station? = .mockWith(),
    listenerQuestion: ListenerQuestion? = .mock,
    createdAt: Date? = Date(),
    updatedAt: Date? = Date()
  ) -> ListenerQuestionAiring {
    ListenerQuestionAiring(
      id: id,
      listenerQuestionId: listenerQuestionId,
      stationId: stationId,
      airtime: airtime,
      station: station,
      listenerQuestion: listenerQuestion,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
