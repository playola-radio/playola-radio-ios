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
  func testHiddenListStationsAreExcluded() {
    // StationList.mocks includes a hidden "in_development_list" containing a
    // visible playola station (id "mock-playola-id"). It must never surface to Siri.
    @Shared(.stationLists) var stationLists = StationList.mocks
    let catalog = StationVoiceCatalog()
    #expect(catalog.suggestedStations().contains { $0.id == "mock-playola-id" } == false)
    #expect(catalog.station(id: "mock-playola-id") == nil)
    #expect(catalog.match(id: "mock-playola-id") == nil)
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
}
