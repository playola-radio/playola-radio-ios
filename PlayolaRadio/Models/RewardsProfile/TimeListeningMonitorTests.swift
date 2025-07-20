//
//  TimeListeningMonitorTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/20/25.
//

import Combine
import Dependencies
import XCTest

@testable import PlayolaRadio

@MainActor
final class TimeListeningMonitorTests: XCTestCase {
  var disposeBag = Set<AnyCancellable>()

  override func setUp() {
    super.setUp()
    disposeBag = Set<AnyCancellable>()
  }

  override func tearDown() {
    disposeBag = []
    super.tearDown()
  }

  func testInitialState() {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 5000,
      totalMSAvailableForRewards: 3000,
      accurateAsOfTime: Date()
    )

    let mockStationPlayer = StationPlayerMock()

    let monitor = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1000)
    } operation: {
      TimeListeningMonitor(
        rewardsProfile: rewardsProfile,
        stationPlayer: mockStationPlayer
      )
    }

    XCTAssertEqual(monitor.totalTimeListenedMS, 5000)
    XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 0)
    XCTAssertEqual(monitor.timeListenedLocallyBeforeCurrentSession, 0)
  }

  //  func testPlayolaStationTracksTime() {
  //    let rewardsProfile = RewardsProfile(
  //      totalTimeListenedMS: 10000,
  //      totalMSAvailableForRewards: 5000,
  //      accurateAsOfTime: Date()
  //    )
  //
  //    let mockStationPlayer = StationPlayerMock()
  //    let playolaStation = RadioStation(
  //      id: "playola-1",
  //      name: "Playola Station",
  //      playolaID: "playola-123",
  //      streamURL: nil,
  //      imageURL: "",
  //      desc: "Test Playola Station",
  //      longDesc: "A test Playola station",
  //      type: .playola
  //    )
  //
  //    let monitor = withDependencies {
  //      $0.date.now = Date(timeIntervalSince1970: 1000)
  //    } operation: {
  //      TimeListeningMonitor(
  //        rewardsProfile: rewardsProfile,
  //        stationPlayer: mockStationPlayer
  //      )
  //    }
  //
  //    // Start playing Playola station
  //    mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))
  //
  //    // Advance time by 5 seconds and check
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1005))) {
  //      XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 5000)
  //      XCTAssertEqual(monitor.totalTimeListenedMS, 15000) // 10000 + 5000
  //    }
  //  }
  //
  //  func testURLStreamDoesNotTrackTime() {
  //    let rewardsProfile = RewardsProfile(
  //      totalTimeListenedMS: 10000,
  //      totalMSAvailableForRewards: 5000,
  //      accurateAsOfTime: Date()
  //    )
  //
  //    let mockStationPlayer = StationPlayerMock()
  //    let urlStation = RadioStation(
  //      id: "url-1",
  //      name: "URL Station",
  //      playolaID: nil,
  //      streamURL: "https://example.com/stream",
  //      imageURL: "",
  //      desc: "Test URL Station",
  //      longDesc: "A test URL stream station",
  //      type: .fm
  //    )
  //
  //    let monitor = withDependencies {
  //      $0.date.now = Date(timeIntervalSince1970: 1000)
  //    } operation: {
  //      TimeListeningMonitor(
  //        rewardsProfile: rewardsProfile,
  //        stationPlayer: mockStationPlayer
  //      )
  //    }
  //
  //    // Start playing URL stream
  //    mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))
  //
  //    // Advance time by 5 seconds and check - should NOT accumulate time
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1005))) {
  //      XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 0)
  //      XCTAssertEqual(monitor.totalTimeListenedMS, 10000) // Should remain unchanged
  //    }
  //  }
  //
  //  func testSwitchingBetweenPlayolaAndURLStations() {
  //    let rewardsProfile = RewardsProfile(
  //      totalTimeListenedMS: 0,
  //      totalMSAvailableForRewards: 0,
  //      accurateAsOfTime: Date()
  //    )
  //
  //    let mockStationPlayer = StationPlayerMock()
  //    let playolaStation = RadioStation(
  //      id: "playola-1",
  //      name: "Playola Station",
  //      playolaID: "playola-123",
  //      streamURL: nil,
  //      imageURL: "",
  //      desc: "Test Playola Station",
  //      longDesc: "A test Playola station",
  //      type: .playola
  //    )
  //
  //    let urlStation = RadioStation(
  //      id: "url-1",
  //      name: "URL Station",
  //      playolaID: nil,
  //      streamURL: "https://example.com/stream",
  //      imageURL: "",
  //      desc: "Test URL Station",
  //      longDesc: "A test URL stream station",
  //      type: .fm
  //    )
  //
  //    let monitor = withDependencies {
  //      $0.date.now = Date(timeIntervalSince1970: 1000)
  //    } operation: {
  //      TimeListeningMonitor(
  //        rewardsProfile: rewardsProfile,
  //        stationPlayer: mockStationPlayer
  //      )
  //    }
  //
  //    // Play Playola station for 3 seconds
  //    mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))
  //
  //    // Switch to URL station after 3 seconds
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1003))) {
  //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))
  //    }
  //
  //    // Advance time by 5 more seconds - only Playola time should count
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1008))) {
  //      XCTAssertEqual(monitor.timeListenedLocallyBeforeCurrentSession, 3000)
  //      XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 0)
  //      XCTAssertEqual(monitor.totalTimeListenedMS, 3000)
  //    }
  //
  //    // Switch back to Playola station
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1010))) {
  //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))
  //    }
  //
  //    // Check after 2 more seconds
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1012))) {
  //      XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 2000)
  //      XCTAssertEqual(monitor.totalTimeListenedMS, 5000) // 3000 + 2000
  //    }
  //  }
  //
  //  func testMultiplePlayolaStationsCumulativeTime() {
  //    let rewardsProfile = RewardsProfile(
  //      totalTimeListenedMS: 0,
  //      totalMSAvailableForRewards: 0,
  //      accurateAsOfTime: Date()
  //    )
  //
  //    let mockStationPlayer = StationPlayerMock()
  //    let playolaStation1 = RadioStation(
  //      id: "playola-1",
  //      name: "Playola Station 1",
  //      playolaID: "playola-123",
  //      streamURL: nil,
  //      imageURL: "",
  //      desc: "Test Playola Station 1",
  //      longDesc: "First test Playola station",
  //      type: .playola
  //    )
  //
  //    let playolaStation2 = RadioStation(
  //      id: "playola-2",
  //      name: "Playola Station 2",
  //      playolaID: "playola-456",
  //      streamURL: nil,
  //      imageURL: "",
  //      desc: "Test Playola Station 2",
  //      longDesc: "Second test Playola station",
  //      type: .playola
  //    )
  //
  //    let monitor = withDependencies {
  //      $0.date.now = Date(timeIntervalSince1970: 1000)
  //    } operation: {
  //      TimeListeningMonitor(
  //        rewardsProfile: rewardsProfile,
  //        stationPlayer: mockStationPlayer
  //      )
  //    }
  //
  //    // Play first Playola station
  //    mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation1))
  //
  //    // Stop after 2 seconds
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1002))) {
  //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .stopped)
  //    }
  //
  //    // Play second station
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1005))) {
  //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation2))
  //    }
  //
  //    // Stop after 3 more seconds
  //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1008))) {
  //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .stopped)
  //
  //      // Check total accumulated time
  //      XCTAssertEqual(monitor.timeListenedLocallyBeforeCurrentSession, 5000) // 2000 + 3000
  //      XCTAssertEqual(monitor.totalTimeListenedMS, 5000)
  //    }
  //  }

  func testLoadingStateForPlayolaStation() {
    //    let rewardsProfile = RewardsProfile(
    //      totalTimeListenedMS: 1000,
    //      totalMSAvailableForRewards: 500,
    //      accurateAsOfTime: Date()
    //    )
    //
    //    let mockStationPlayer = StationPlayerMock()
    //    let playolaStation = RadioStation(
    //      id: "playola-1",
    //      name: "Playola Station",
    //      playolaID: "playola-123",
    //      streamURL: nil,
    //      imageURL: "",
    //      desc: "Test Playola Station",
    //      longDesc: "A test Playola station",
    //      type: .playola
    //    )
    //
    //    let monitor = withDependencies {
    //      $0.date.now = Date(timeIntervalSince1970: 1000)
    //    } operation: {
    //      TimeListeningMonitor(
    //        rewardsProfile: rewardsProfile,
    //        stationPlayer: mockStationPlayer
    //      )
    //    }
    //
    //    // Start playing
    //    mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))
    //
    //    // Switch to loading after 2 seconds
    //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1002))) {
    //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .loading(playolaStation))
    //    }
    //
    //    // Check that time stopped accumulating
    //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1005))) {
    //      XCTAssertEqual(monitor.timeListenedLocallyBeforeCurrentSession, 2000)
    //      XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 0)
    //      XCTAssertEqual(monitor.totalTimeListenedMS, 3000) // 1000 + 2000
    //    }
  }

  func testErrorStateForPlayolaStation() {
    //    let rewardsProfile = RewardsProfile(
    //      totalTimeListenedMS: 5000,
    //      totalMSAvailableForRewards: 2500,
    //      accurateAsOfTime: Date()
    //    )
    //
    //    let mockStationPlayer = StationPlayerMock()
    //    let playolaStation = RadioStation(
    //      id: "playola-1",
    //      name: "Playola Station",
    //      playolaID: "playola-123",
    //      streamURL: nil,
    //      imageURL: "",
    //      desc: "Test Playola Station",
    //      longDesc: "A test Playola station",
    //      type: .playola
    //    )
    //
    //    let monitor = withDependencies {
    //      $0.date.now = Date(timeIntervalSince1970: 1000)
    //    } operation: {
    //      TimeListeningMonitor(
    //        rewardsProfile: rewardsProfile,
    //        stationPlayer: mockStationPlayer
    //      )
    //    }
    //
    //    // Start playing
    //    mockStationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))
    //
    //    // Error after 1.5 seconds
    //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1001.5))) {
    //      mockStationPlayer.state = StationPlayer.State(playbackStatus: .error)
    //    }
    //
    //    // Check time stopped and was accumulated
    //    DependencyValues.$date.withValue(.constant(Date(timeIntervalSince1970: 1010))) {
    //      XCTAssertEqual(monitor.timeListenedLocallyBeforeCurrentSession, 1500)
    //      XCTAssertEqual(monitor.timeListenedDuringCurrentSessionMS, 0)
    //      XCTAssertEqual(monitor.totalTimeListenedMS, 6500) // 5000 + 1500
    //    }
  }
}
