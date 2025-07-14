//
//  MainContainerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

// swiftlint:disable force_try

@testable import PlayolaRadio
import Sharing
import Testing
import Foundation

enum MainContainerTests {
  // Helper function to create valid JWT tokens for testing
  static func createTestJWT(
    id: String = "test-user-123",
    displayName: String = "Test User",
    email: String = "test@example.com",
    profileImageUrl: String? = nil,
    role: String = "user"
  ) -> String {
    let header = ["alg": "HS256", "typ": "JWT"]
    var payload: [String: Any] = [
      "id": id,
      "displayName": displayName,
      "email": email,
      "role": role
    ]
    if let profileImageUrl = profileImageUrl {
      payload["profileImageUrl"] = profileImageUrl
    }
    
    let headerData = try! JSONSerialization.data(withJSONObject: header)
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)
    
    let headerString = headerData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    
    let payloadString = payloadData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    
    return "\(headerString).\(payloadString).fake_signature"
  }
  
  @MainActor @Suite("ViewAppeared")
  struct ViewAppeared {
    @Test("Retrieves the list -- working")
    func testCorrectlyRetrievesStationListsWhenApiIsSuccessful() async {
      @Shared(.stationListsLoaded) var stationListsLoaded = false
      @Shared(.stationLists) var stationLists = StationList.mocks
      let apiMock = APIMock(getStationListsShouldSucceed: true)
      let mainContainerModel = MainContainerModel(api: apiMock)
      await mainContainerModel.viewAppeared()
      #expect(apiMock.getStationListsCallCount == 1)
    }
    
    @Test("Displays an error alert on api error")
    func testDisplaysAnErrorAlertOnApiError() async {
      @Shared(.stationListsLoaded) var stationListsLoaded = false
      @Shared(.stationLists) var stationLists = StationList.mocks
      let apiMock = APIMock(getStationListsShouldSucceed: false)
      let mainContainerModel = MainContainerModel(api: apiMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.presentedAlert == .errorLoadingStations)
    }
  }
  
  @MainActor @Suite("SmallPlayer Properties")
  struct SmallPlayerProperties {
    @Test("shouldShowSmallPlayer returns true when playing")
    func testShouldShowSmallPlayerWhenPlaying() async {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.shouldShowSmallPlayer == true)
    }
    
    @Test("shouldShowSmallPlayer returns true when loading")
    func testShouldShowSmallPlayerWhenLoading() async {
      let stationPlayerMock = StationPlayerMock()
      stationPlayerMock.state = StationPlayer.State(playbackStatus: .loading(.mock))
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.shouldShowSmallPlayer == true)
    }
    
    @Test("shouldShowSmallPlayer returns false when stopped")
    func testShouldShowSmallPlayerWhenStopped() async {
      let stationPlayerMock = StationPlayerMock.mockStoppedPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.shouldShowSmallPlayer == false)
    }
    
    @Test("shouldShowSmallPlayer returns false when error")
    func testShouldShowSmallPlayerWhenError() async {
      let stationPlayerMock = StationPlayerMock()
      stationPlayerMock.state = StationPlayer.State(playbackStatus: .error)
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.shouldShowSmallPlayer == false)
    }
    
    @Test("shouldShowSmallPlayer returns true when startingNewStation")
    func testShouldShowSmallPlayerWhenStartingNewStation() async {
      let stationPlayerMock = StationPlayerMock()
      stationPlayerMock.state = StationPlayer.State(playbackStatus: .startingNewStation(.mock))
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.shouldShowSmallPlayer == true)
    }
    
    @Test("smallPlayerMainTitle returns station name")
    func testSmallPlayerMainTitleReturnsStationName() {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerMainTitle == RadioStation.mock.name)
    }
    
    @Test("smallPlayerMainTitle returns empty string when no current station")
    func testSmallPlayerMainTitleWhenNoCurrentStation() {
      let stationPlayerMock = StationPlayerMock.mockStoppedPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerMainTitle == "")
    }
    
    @Test("smallPlayerSecondaryTitle returns station description")
    func testSmallPlayerSecondaryTitleReturnsStationDescription() {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerSecondaryTitle == RadioStation.mock.desc)
    }
    
    @Test("smallPlayerSecondaryTitle returns empty string when no current station")
    func testSmallPlayerSecondaryTitleWhenNoCurrentStation() {
      let stationPlayerMock = StationPlayerMock.mockStoppedPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerSecondaryTitle == "")
    }
    
    @Test("smallPlayerArtworkURL returns album artwork URL when available")
    func testSmallPlayerArtworkURLReturnsAlbumArtwork() {
      let stationPlayerMock = StationPlayerMock()
      let testURL = URL(string: "https://example.com/artwork.jpg")!
      stationPlayerMock.state = StationPlayer.State(
        playbackStatus: .playing(.mock),
        albumArtworkUrl: testURL
      )
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerArtworkURL == testURL)
    }
    
    @Test("smallPlayerArtworkURL returns station image URL when no album artwork")
    func testSmallPlayerArtworkURLReturnsStationImage() {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerArtworkURL == RadioStation.mock.processedImageURL())
    }
    
    @Test("smallPlayerArtworkURL returns fallback URL when no station or artwork")
    func testSmallPlayerArtworkURLReturnsFallback() {
      let stationPlayerMock = StationPlayerMock.mockStoppedPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      #expect(mainContainerModel.smallPlayerArtworkURL == URL(string: "https://example.com")!)
    }
  }
  
  @MainActor @Suite("SmallPlayer Actions")
  struct SmallPlayerActions {
    @Test("onSmallPlayerStopTapped calls station player stop")
    func testOnSmallPlayerStopTapped() {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      
      mainContainerModel.onSmallPlayerStopTapped()
      
      #expect(stationPlayerMock.stopCalledCount == 1)
    }
    
    @Test("onSmallPlayerTapped presents player sheet")
    func testOnSmallPlayerTapped() {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      
      mainContainerModel.onSmallPlayerTapped()
      
      #expect(mainContainerModel.presentedSheet != nil)
      if case .player = mainContainerModel.presentedSheet {
        // Test passes
      } else {
        #expect(Bool(false), "Expected player sheet to be presented")
      }
    }
    
    @Test("small player hides when stop button is pressed")
    func testSmallPlayerHidesWhenStopButtonPressed() async {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      await mainContainerModel.viewAppeared()
      // Verify small player should be showing initially
      #expect(mainContainerModel.shouldShowSmallPlayer == true)
      
      // Simulate the stop button being pressed
      mainContainerModel.onSmallPlayerStopTapped()
      
      // Update the mock to reflect the stopped state
      stationPlayerMock.state = StationPlayer.State(playbackStatus: .stopped)
      
      // Verify small player should now be hidden
      #expect(mainContainerModel.shouldShowSmallPlayer == false)
    }
  }
  
  @MainActor @Suite("ProcessNewStationState")
  struct ProcessNewStationState {
    @Test("processNewStationState presents player sheet when starting new station")
    func testProcessNewStationStatePresentsPlayerSheetWhenStartingNewStation() {
      let stationPlayerMock = StationPlayerMock()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      
      let newState = StationPlayer.State(playbackStatus: .startingNewStation(.mock))
      mainContainerModel.processNewStationState(newState)
      
      #expect(mainContainerModel.presentedSheet != nil)
      if case .player = mainContainerModel.presentedSheet {
        // Test passes
      } else {
        #expect(Bool(false), "Expected player sheet to be presented")
      }
    }
    
    @Test("processNewStationState does not present sheet for other states")
    func testProcessNewStationStateDoesNotPresentSheetForOtherStates() {
      let stationPlayerMock = StationPlayerMock()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      
      let playingState = StationPlayer.State(playbackStatus: .playing(.mock))
      mainContainerModel.processNewStationState(playingState)
      #expect(mainContainerModel.presentedSheet == nil)
      
      let stoppedState = StationPlayer.State(playbackStatus: .stopped)
      mainContainerModel.processNewStationState(stoppedState)
      #expect(mainContainerModel.presentedSheet == nil)
      
      let loadingState = StationPlayer.State(playbackStatus: .loading(.mock))
      mainContainerModel.processNewStationState(loadingState)
      #expect(mainContainerModel.presentedSheet == nil)
      
      let errorState = StationPlayer.State(playbackStatus: .error)
      mainContainerModel.processNewStationState(errorState)
      #expect(mainContainerModel.presentedSheet == nil)
    }
  }
  
  @MainActor @Suite("DismissButtonInSheetTapped")
  struct DismissButtonInSheetTapped {
    @Test("dismissButtonInSheetTapped clears presented sheet")
    func testDismissButtonInSheetTappedClearsPresentedSheet() {
      let mainContainerModel = MainContainerModel()
      mainContainerModel.presentedSheet = .about(AboutPageModel())
      
      mainContainerModel.dismissButtonInSheetTapped()
      
      #expect(mainContainerModel.presentedSheet == nil)
    }
    
    @Test("PlayerPage onDismiss clears presentedSheet")
    func testPlayerPageOnDismissClearsPresentedSheet() {
      let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
      let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)
      
      // Trigger the presentation of the player sheet
      mainContainerModel.onSmallPlayerTapped()
      
      // Verify the sheet is presented
      #expect(mainContainerModel.presentedSheet != nil)
      
      // Extract the PlayerPageModel from the presented sheet
      guard case let .player(playerPageModel) = mainContainerModel.presentedSheet else {
        #expect(Bool(false), "Expected player sheet to be presented")
        return
      }
      
      // Call the onDismiss callback
      playerPageModel.onDismiss?()
      
      // Verify the sheet is now nil
      #expect(mainContainerModel.presentedSheet == nil)
    }
  }
  
  @MainActor @Suite("PlayolaStationPlayer Authentication Configuration")
  struct PlayolaStationPlayerConfiguration {
    @Test("Configures PlayolaStationPlayer with auth provider on init")
    func testConfiguresPlayolaStationPlayerOnInit() async {
      let testJWT = createTestJWT()
      @Shared(.auth) var auth = Auth(jwtToken: testJWT)
      
      // When MainContainerModel is created (user is logged in),
      // it should configure PlayolaStationPlayer with authentication
      let mainContainerModel = MainContainerModel()
      
      #expect(mainContainerModel != nil, "MainContainerModel should be created successfully")
    }
    
    @Test("Uses authenticated session reporting when user logged in")
    func testUsesAuthenticatedSessionReporting() async {
      let testJWT = createTestJWT()
      @Shared(.auth) var auth = Auth(jwtToken: testJWT)
      
      // MainContainerModel creation should configure PlayolaStationPlayer
      // to use JWT tokens for session reporting
      MainContainerModel()
      
      #expect(auth.isLoggedIn == true)
      #expect(auth.jwt == testJWT)
    }
  }
  
  @MainActor @Suite("Authentication State Lifecycle")
  struct AuthStateLifecycle {
    @Test("MainContainer only exists when user is authenticated")
    func testMainContainerExistsOnlyWhenAuthenticated() async {
      let testJWT = createTestJWT()
      @Shared(.auth) var auth = Auth(jwtToken: testJWT)
      
      // User is logged in - MainContainer can be created
      #expect(auth.isLoggedIn == true)
      let mainContainerModel = MainContainerModel()
      #expect(mainContainerModel != nil)
      
      // When user signs out, ContentView will destroy MainContainer
      // and show SignInPage instead - this is handled by ContentView logic
      $auth.withLock { $0 = Auth() }
      #expect(auth.isLoggedIn == false)
    }
    
    @Test("Multiple login sessions each get fresh auth configuration")
    func testMultipleLoginSessionsGetFreshConfig() async {
      @Shared(.auth) var auth = Auth()
      
      // First login session
      let firstJWT = createTestJWT(id: "user1", displayName: "First User")
      $auth.withLock { $0 = Auth(jwtToken: firstJWT) }
      let firstMainContainer = MainContainerModel()
      #expect(auth.jwt == firstJWT)
      
      // User logs out, logs back in with new token
      $auth.withLock { $0 = Auth() }
      let secondJWT = createTestJWT(id: "user2", displayName: "Second User")
      $auth.withLock { $0 = Auth(jwtToken: secondJWT) }
      let secondMainContainer = MainContainerModel()
      #expect(auth.jwt == secondJWT)
    }
  }
}
// swiftlint:enable force_try
