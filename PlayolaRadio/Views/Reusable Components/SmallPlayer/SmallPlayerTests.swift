//
//  SmallPlayerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/21/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class SmallPlayerTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Clear shared state before each test
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock { $0 = nil }
  }

  // MARK: - Main Title Tests

  func testMainTitle_ReturnsStationNameWhenAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.mainTitle, mockStation.name)
  }

  func testMainTitle_ReturnsEmptyStringWhenNoStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?

    $nowPlaying.withLock { $0 = NowPlaying() }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.mainTitle, "")
  }

  func testMainTitle_ReturnsEmptyStringWhenNowPlayingIsNil() {
    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.mainTitle, "")
  }

  // MARK: - Secondary Title Tests

  func testSecondaryTitle_ReturnsArtistAndTitleWhenAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.secondaryTitle, "Test Artist - Test Song")
  }

  func testSecondaryTitle_ReturnsStationDescWhenNoArtistTitle() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.secondaryTitle, mockStation.description)
  }

  func testSecondaryTitle_ReturnsStationDescWhenOnlyArtistAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.secondaryTitle, mockStation.description)
  }

  func testSecondaryTitle_ReturnsStationDescWhenOnlyTitleAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.secondaryTitle, mockStation.description)
  }

  func testSecondaryTitle_ReturnsEmptyStringWhenNothingAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?

    $nowPlaying.withLock { $0 = NowPlaying() }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.secondaryTitle, "")
  }

  // MARK: - Artwork URL Tests

  func testArtworkURL_ReturnsAlbumArtworkWhenAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let testURL = URL(string: "https://example.com/album.jpg")!
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        albumArtworkUrl: testURL,
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.artworkURL, testURL)
  }

  func testArtworkURL_ReturnsStationImageWhenNoAlbumArtwork() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.artworkURL, mockStation.processedImageURL())
  }

  func testArtworkURL_ReturnsFallbackWhenNothingAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?

    $nowPlaying.withLock { $0 = NowPlaying() }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.artworkURL, URL(string: "https://example.com")!)
  }

  func testArtworkURL_ReturnsFallbackWhenNowPlayingIsNil() {
    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.artworkURL, URL(string: "https://example.com")!)
  }

  // MARK: - State Change Tests

  func testSmallPlayer_UpdatesWhenNowPlayingChanges() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    // Initial state - no track info
    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.mainTitle, mockStation.name)
    XCTAssertEqual(smallPlayer.secondaryTitle, mockStation.description)

    // Update with artist/title - should now show track info
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "New Artist",
        titlePlaying: "New Song",
        currentStation: mockStation
      )
    }

    XCTAssertEqual(smallPlayer.mainTitle, mockStation.name)
    XCTAssertEqual(smallPlayer.secondaryTitle, "New Artist - New Song")
  }

  func testSmallPlayer_HandlesNilToDataTransition() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    let smallPlayer = SmallPlayer()

    // Initially nil
    XCTAssertEqual(smallPlayer.mainTitle, "")
    XCTAssertEqual(smallPlayer.secondaryTitle, "")

    // Set data
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    XCTAssertEqual(smallPlayer.mainTitle, mockStation.name)
    XCTAssertEqual(smallPlayer.secondaryTitle, "Test Artist - Test Song")
  }

  func testSmallPlayer_HandlesDataToNilTransition() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock

    // Start with data
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.mainTitle, mockStation.name)
    XCTAssertEqual(smallPlayer.secondaryTitle, "Test Artist - Test Song")

    // Clear data
    $nowPlaying.withLock { $0 = nil }

    XCTAssertEqual(smallPlayer.mainTitle, "")
    XCTAssertEqual(smallPlayer.secondaryTitle, "")
  }

  // MARK: - Integration Tests with Spin Data

  func testSmallPlayer_DisplaysSpinDataCorrectly() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    let mockStation = AnyStation.mock
    let mockSpin = Spin.mock
    let testArtist = "Test Artist"
    let testTitle = "Test Song"
    let testImageUrl = URL(string: "https://example.com/spin-artwork.jpg")!

    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: testArtist,
        titlePlaying: testTitle,
        albumArtworkUrl: testImageUrl,
        playolaSpinPlaying: mockSpin,
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    XCTAssertEqual(smallPlayer.mainTitle, mockStation.name)
    XCTAssertEqual(smallPlayer.secondaryTitle, "\(testArtist) - \(testTitle)")
    XCTAssertEqual(smallPlayer.artworkURL, testImageUrl)
  }
}
