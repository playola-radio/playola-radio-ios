import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationVoiceCatalogTests {
  @Test
  func testNormalizeLowercasesStripsPunctuationAndPossessive() {
    #expect(StationVoiceCatalog.normalize("Radney Foster's Station") == "radney foster")
    #expect(StationVoiceCatalog.normalize("Bordertown Radio!") == "bordertown")
    #expect(StationVoiceCatalog.normalize("  KOKE  FM ") == "koke fm")
  }

  @Test
  func testSuggestedStationsFMLabelIsStationName() {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let koke = StationVoiceCatalog().suggestedStations().first { $0.id == "koke-fm-id" }
    #expect(koke?.label == "KOKE FM")
  }

  @Test
  func testSuggestedStationsArtistLabelIsArtistPossessive() {
    let artistList = StationList.mockArtistList(items: [
      APIStationItem(
        sortOrder: 0,
        station: Station.mockWith(
          id: "rf-id", name: "Bordertown Radio", curatorName: "Radney Foster"), urlStation: nil)
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [artistList])
    let match = StationVoiceCatalog().suggestedStations().first { $0.id == "rf-id" }
    #expect(match?.label == "Radney Foster's Station")
  }

  @Test
  func testMatchesResolvesByStationNameAndCuratorName() {
    let artistList = StationList.mockArtistList(items: [
      APIStationItem(
        sortOrder: 0,
        station: Station.mockWith(
          id: "rf-id", name: "Bordertown Radio", curatorName: "Radney Foster"), urlStation: nil)
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [artistList])
    let catalog = StationVoiceCatalog()
    #expect(catalog.matches(query: "Bordertown Radio").first?.id == "rf-id")
    #expect(catalog.matches(query: "Radney Foster").first?.id == "rf-id")
    #expect(catalog.matches(query: "Radney Foster's Station").first?.id == "rf-id")
  }

  @Test
  func testMatchesFailsClosedOnNoConfidentMatch() {
    @Shared(.stationLists) var stationLists = StationList.mocks
    #expect(StationVoiceCatalog().matches(query: "totally unrelated zzzz").isEmpty)
  }

  @Test
  func testMatchByIdReturnsLabel() {
    @Shared(.stationLists) var stationLists = StationList.mocks
    #expect(StationVoiceCatalog().match(id: "koke-fm-id")?.label == "KOKE FM")
    #expect(StationVoiceCatalog().match(id: "nope") == nil)
  }

  @Test
  func testStationByIdReturnsAnyStation() {
    @Shared(.stationLists) var stationLists = StationList.mocks
    #expect(StationVoiceCatalog().station(id: "koke-fm-id")?.id == "koke-fm-id")
    #expect(StationVoiceCatalog().station(id: "nonexistent") == nil)
  }

  @Test
  func testHiddenAndComingSoonStationsAreIncluded() {
    // Siri fails toward inclusion: a station gated behind the secret-stations
    // unlock everywhere else is still voice-playable. StationList.mocks covers
    // all three gated shapes — a hidden list ("mock-playola-id"), a hidden item
    // ("kftx-id"), and a coming-soon item ("lakes-country-id").
    @Shared(.stationLists) var stationLists = StationList.mocks
    let catalog = StationVoiceCatalog()
    let suggestedIDs = Set(catalog.suggestedStations().map(\.id))
    #expect(suggestedIDs.contains("mock-playola-id"))
    #expect(suggestedIDs.contains("kftx-id"))
    #expect(suggestedIDs.contains("lakes-country-id"))
    #expect(catalog.station(id: "mock-playola-id")?.id == "mock-playola-id")
    #expect(catalog.match(id: "kftx-id")?.label == "97.5 KFTX")
    #expect(catalog.matches(query: "Banned Radio").first?.id == "mock-playola-id")
  }

  @Test
  func testInactiveStationsAreExcluded() {
    // active == false means the app itself refuses to play it (see
    // StationListModel.stationSelected); Siri must not offer a dead station.
    // Covers both station kinds plus the nil-default (nil active == playable).
    let list = StationList.mockArtistList(items: [
      APIStationItem(
        sortOrder: 0, station: nil,
        urlStation: UrlStation.mockWith(id: "dead-url-id", name: "Dead Air FM", active: false)),
      APIStationItem(
        sortOrder: 1,
        station: Station.mockWith(id: "dead-playola-id", name: "Off Air", active: false),
        urlStation: nil),
      APIStationItem(
        sortOrder: 2,
        station: Station.mockWith(id: "nil-active-id", name: "Defaulted", active: nil),
        urlStation: nil),
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [list])
    let catalog = StationVoiceCatalog()
    let ids = Set(catalog.suggestedStations().map(\.id))
    #expect(ids.contains("dead-url-id") == false)
    #expect(ids.contains("dead-playola-id") == false)
    #expect(ids.contains("nil-active-id"))  // nil active defaults to playable
    #expect(catalog.station(id: "dead-playola-id") == nil)
    #expect(catalog.matches(query: "Dead Air FM").isEmpty)
  }

  @Test
  func testStationInMultipleListsIsDedupedKeepingFirstOccurrence() {
    // The same id can live in more than one visible list with a different label
    // per list. It must surface once, and the first list's label wins so
    // catalog-order tie-breaking in matches() stays deterministic.
    let now = Date()
    func list(id: String, sortOrder: Int, label: String) -> StationList {
      StationList(
        id: id, name: id, slug: id, hidden: false, sortOrder: sortOrder,
        createdAt: now, updatedAt: now,
        items: [
          APIStationItem(
            sortOrder: 0, station: nil,
            urlStation: UrlStation.mockWith(id: "dup-id", name: label))
        ])
    }
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [
      list(id: "list-a", sortOrder: 0, label: "First Label FM"),
      list(id: "list-b", sortOrder: 1, label: "Second Label FM"),
    ])
    let catalog = StationVoiceCatalog()
    let dupes = catalog.suggestedStations().filter { $0.id == "dup-id" }
    #expect(dupes.count == 1)
    #expect(dupes.first?.label == "First Label FM")
    #expect(catalog.matches(query: "First Label FM").filter { $0.id == "dup-id" }.count == 1)
  }

  @Test
  func testPlaceholderRowWithNoStationIsSkippedNotCrashed() {
    // The decoder permits a row with neither a playola nor a URL station (e.g. a
    // coming-soon placeholder). Including hidden/coming-soon items must skip such
    // rows, not trap, while still surfacing the real station beside them.
    let list = StationList.mockArtistList(items: [
      APIStationItem(sortOrder: 0, station: nil, urlStation: nil),
      APIStationItem(
        sortOrder: 1, station: nil,
        urlStation: UrlStation.mockWith(id: "real-id", name: "Real FM")),
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [list])
    let catalog = StationVoiceCatalog()
    #expect(catalog.suggestedStations().map(\.id) == ["real-id"])
    #expect(catalog.matches(query: "Real FM").first?.id == "real-id")
  }

  @Test
  func testNormalizeReplacesPunctuationWithSpace() {
    #expect(StationVoiceCatalog.normalize("KOKE-FM") == "koke fm")
    #expect(StationVoiceCatalog.normalize("Q102/Z") == "q102 z")
  }

  @Test
  func testShortFragmentsFailClosed() {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let catalog = StationVoiceCatalog()
    #expect(catalog.matches(query: "k").isEmpty)
    #expect(catalog.matches(query: "fm").isEmpty)
    #expect(catalog.matches(query: "q").isEmpty)
  }

  @Test
  func testLegitimatePartialStillMatches() {
    @Shared(.stationLists) var stationLists = StationList.mocks
    // "koke" is a real prefix of "KOKE FM" and should still resolve.
    #expect(StationVoiceCatalog().matches(query: "koke").first?.id == "koke-fm-id")
  }

  @Test
  func testNormalizeFoldsDiacritics() {
    #expect(StationVoiceCatalog.normalize("Beyoncé") == "beyonce")
  }

  @Test
  func testLongerQueryDoesNotPrefixMatchShortStation() {
    let list = StationList.mockArtistList(items: [
      APIStationItem(
        sortOrder: 0,
        station: Station.mockWith(
          id: "rock-id", name: "Rock", curatorName: "Rock"), urlStation: nil)
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [list])
    #expect(StationVoiceCatalog().matches(query: "rockabilly").isEmpty)
  }
}
