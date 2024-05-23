//
//  NowPlayingPageTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 5/22/24.
//

import ComposableArchitecture
import XCTest
import FRadioPlayer

@testable import PlayolaRadio

final class NowPlayingPageTests: XCTestCase {
  @MainActor
  func testMonitorsStationState() async {
    let (subscribeToPlayerState, sendPlayerState) = AsyncStream.makeStream(of: StationPlayer.State.self)
    let (subscribeToAlbumImageURL, sendAlbumImageURL) = AsyncStream.makeStream(of: URL?.self)

    let store = TestStore(initialState: NowPlayingReducer.State()) {
      NowPlayingReducer()
    } withDependencies: {
      $0.stationPlayer.subscribeToPlayerState = { subscribeToPlayerState }
      $0.stationPlayer.subscribeToAlbumImageURL = { subscribeToAlbumImageURL }
    }

    let monitorStationStoreTask = await store.send(.viewAppeared)

    var currentStation = RadioStation.mock
    currentStation.type = .artist

    let newState = StationPlayer.State(playbackState: .paused,
                                       playerStatus: .loading,
                                       currentStation: currentStation,
                                       nowPlaying: FRadioPlayer.Metadata(
                                        artistName: "Bob Dylan",
                                        trackName: "Sara",
                                        rawValue: nil,
                                        groups: []))
    sendPlayerState.yield(newState)

    await store.receive(\.stationsPlayerStateDidChange) {
      $0.stationPlayerState = newState
    }

    await monitorStationStoreTask.cancel()
  }

  @MainActor
  func testReceivesAnAlbumImageURL() async {
    let (subscribeToPlayerState, sendPlayerState) = AsyncStream.makeStream(of: StationPlayer.State.self)
    let (subscribeToAlbumImageURL, sendAlbumImageURL) = AsyncStream.makeStream(of: URL?.self)

    let store = TestStore(initialState: NowPlayingReducer.State()) {
      NowPlayingReducer()
    } withDependencies: {
      $0.stationPlayer.subscribeToPlayerState = { subscribeToPlayerState }
      $0.stationPlayer.subscribeToAlbumImageURL = { subscribeToAlbumImageURL }
    }

    let monitorStationStoreTask = await store.send(.viewAppeared)

    var currentStation = RadioStation.mock
    currentStation.type = .artist

    let newURL = URL(string: "https://testimages.com")!
    sendAlbumImageURL.yield(newURL)

    await store.receive(\.albumArtworkDidChange) {
      $0.albumArtworkURL = newURL
    }

    await monitorStationStoreTask.cancel()
  }
  
  @MainActor
  func testUsesStationArtIfANilAlbumImageURL() async {
    let (subscribeToPlayerState, sendPlayerState) = AsyncStream.makeStream(of: StationPlayer.State.self)
    let (subscribeToAlbumImageURL, sendAlbumImageURL) = AsyncStream.makeStream(of: URL?.self)

    let store = TestStore(initialState: NowPlayingReducer.State(
      stationPlayerState: StationPlayer.State(playbackState: .playing, currentStation: RadioStation.mock),
      albumArtworkURL: URL(string: "https://testimages.com")!
    )) {
      NowPlayingReducer()
    } withDependencies: {
      $0.stationPlayer.subscribeToPlayerState = { subscribeToPlayerState }
      $0.stationPlayer.subscribeToAlbumImageURL = { subscribeToAlbumImageURL }
    }

    let monitorStationStoreTask = await store.send(.viewAppeared)

    sendAlbumImageURL.yield(nil)

    await store.receive(\.albumArtworkDidChange) {
      $0.albumArtworkURL = RadioStation.mock.processedImageURL()
    }

    await monitorStationStoreTask.cancel()
  }

  @MainActor
  func testUsesPlayolaIconIfNilAlbumImageURLAndNilStationArt() async {
    let (subscribeToPlayerState, sendPlayerState) = AsyncStream.makeStream(of: StationPlayer.State.self)
    let (subscribeToAlbumImageURL, sendAlbumImageURL) = AsyncStream.makeStream(of: URL?.self)

    let store = TestStore(initialState: NowPlayingReducer.State(
      stationPlayerState: StationPlayer.State(playbackState: .playing, currentStation: nil),
      albumArtworkURL: URL(string: "https://testimages.com")!
    )) {
      NowPlayingReducer()
    } withDependencies: {
      $0.stationPlayer.subscribeToPlayerState = { subscribeToPlayerState }
      $0.stationPlayer.subscribeToAlbumImageURL = { subscribeToAlbumImageURL }
    }

    let monitorStationStoreTask = await store.send(.viewAppeared)

    sendAlbumImageURL.yield(nil)

    await store.receive(\.albumArtworkDidChange) {
      $0.albumArtworkURL = NowPlayingReducer.placeholderImageURL
    }

    await monitorStationStoreTask.cancel()
  }

  // TODO: Test that stop is called on stationPlayer and dimsiss() is called on .playButtonTapped action

}

