//
//  SmallPlayerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/21/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct SmallPlayerTests {

  // MARK: - Main Title Tests

  @Test
  func testMainTitleReturnsStationNameWhenAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.mainTitle == mockStation.name)
  }

  @Test
  func testMainTitleReturnsEmptyStringWhenNoStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    $nowPlaying.withLock { $0 = NowPlaying() }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.mainTitle == "")
  }

  @Test
  func testMainTitleReturnsEmptyStringWhenNowPlayingIsNil() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.mainTitle == "")
  }

  // MARK: - Secondary Title Tests

  @Test
  func testSecondaryTitleReturnsArtistAndTitleWhenAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == "Test Artist - Test Song")
  }

  @Test
  func testSecondaryTitleReturnsStationDescWhenNoArtistTitle() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == mockStation.description)
  }

  @Test
  func testSecondaryTitleReturnsLoadingWhenPlaybackStatusIsLoading() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        currentStation: mockStation,
        playbackStatus: .loading(mockStation)
      )
    }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == "Loading...")
  }

  @Test
  func testSecondaryTitleReturnsLoadingWhenLoadingEvenWithTrackInfo() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        titlePlaying: "Test Song",
        currentStation: mockStation,
        playbackStatus: .loading(mockStation)
      )
    }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == "Loading...")
  }

  @Test
  func testSecondaryTitleReturnsStationDescWhenOnlyArtistAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == mockStation.description)
  }

  @Test
  func testSecondaryTitleReturnsStationDescWhenOnlyTitleAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == mockStation.description)
  }

  @Test
  func testSecondaryTitleReturnsEmptyStringWhenNothingAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    $nowPlaying.withLock { $0 = NowPlaying() }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.secondaryTitle == "")
  }

  // MARK: - Artwork URL Tests

  @Test
  func testArtworkURLReturnsAlbumArtworkWhenAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let testURL = URL(string: "https://example.com/album.jpg")!
    let mockStation = AnyStation.mock

    $nowPlaying.withLock {
      $0 = NowPlaying(
        albumArtworkUrl: testURL,
        currentStation: mockStation
      )
    }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.artworkURL == testURL)
  }

  @Test
  func testArtworkURLReturnsStationImageWhenNoAlbumArtwork() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.artworkURL == mockStation.processedImageURL())
  }

  @Test
  func testArtworkURLReturnsFallbackWhenNothingAvailable() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    $nowPlaying.withLock { $0 = NowPlaying() }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.artworkURL == URL(string: "https://example.com")!)
  }

  @Test
  func testArtworkURLReturnsFallbackWhenNowPlayingIsNil() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.artworkURL == URL(string: "https://example.com")!)
  }

  // MARK: - State Change Tests

  @Test
  func testSmallPlayerUpdatesWhenNowPlayingChanges() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    // Initial state - no track info
    $nowPlaying.withLock { $0 = NowPlaying(currentStation: mockStation) }

    let smallPlayer = SmallPlayer()
    #expect(smallPlayer.mainTitle == mockStation.name)
    #expect(smallPlayer.secondaryTitle == mockStation.description)

    // Update with artist/title - should now show track info
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "New Artist",
        titlePlaying: "New Song",
        currentStation: mockStation
      )
    }

    #expect(smallPlayer.mainTitle == mockStation.name)
    #expect(smallPlayer.secondaryTitle == "New Artist - New Song")
  }

  @Test
  func testSmallPlayerHandlesNilToDataTransition() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let mockStation = AnyStation.mock

    let smallPlayer = SmallPlayer()

    // Initially nil
    #expect(smallPlayer.mainTitle == "")
    #expect(smallPlayer.secondaryTitle == "")

    // Set data
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Test Artist",
        titlePlaying: "Test Song",
        currentStation: mockStation
      )
    }

    #expect(smallPlayer.mainTitle == mockStation.name)
    #expect(smallPlayer.secondaryTitle == "Test Artist - Test Song")
  }

  @Test
  func testSmallPlayerHandlesDataToNilTransition() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
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
    #expect(smallPlayer.mainTitle == mockStation.name)
    #expect(smallPlayer.secondaryTitle == "Test Artist - Test Song")

    // Clear data
    $nowPlaying.withLock { $0 = nil }

    #expect(smallPlayer.mainTitle == "")
    #expect(smallPlayer.secondaryTitle == "")
  }

  // MARK: - Integration Tests with Spin Data

  @Test
  func testSmallPlayerDisplaysSpinDataCorrectly() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
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
    #expect(smallPlayer.mainTitle == mockStation.name)
    #expect(smallPlayer.secondaryTitle == "\(testArtist) - \(testTitle)")
    #expect(smallPlayer.artworkURL == testImageUrl)
  }
}

// swiftlint:enable redundant_optional_initialization
