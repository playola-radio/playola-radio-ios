import AppIntents

struct RadioStationEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Station")
  }
  static var defaultQuery = RadioStationEntityQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct RadioStationEntityQuery: EntityQuery, EntityStringQuery {
  @MainActor
  func entities(for identifiers: [String]) async throws -> [RadioStationEntity] {
    let catalog = StationVoiceCatalog()
    return identifiers.compactMap { id in
      catalog.match(id: id).map { RadioStationEntity(id: $0.id, name: $0.label) }
    }
  }

  @MainActor
  func suggestedEntities() async throws -> [RadioStationEntity] {
    StationVoiceCatalog().suggestedStations().map { RadioStationEntity(id: $0.id, name: $0.label) }
  }

  @MainActor
  func entities(matching string: String) async throws -> [RadioStationEntity] {
    StationVoiceCatalog().matches(query: string).map {
      RadioStationEntity(id: $0.id, name: $0.label)
    }
  }
}
