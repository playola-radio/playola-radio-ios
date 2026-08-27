//
//  ScreenshotHarness.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/26/26.
//

#if DEBUG
  import Dependencies
  import Foundation
  import IdentifiedCollections
  import PlayolaPlayer
  import Sharing
  import SwiftUI

  /// Dev-only entry point for automated App Store screenshots.
  ///
  /// Activated by launching the app with the `SCREENSHOT_PAGE` environment variable
  /// (from the host: `SIMCTL_CHILD_SCREENSHOT_PAGE=stations xcrun simctl launch …`).
  /// Renders the real `MainContainer` with every input pinned to fixtures — shared
  /// state is seeded and the API dependency is mocked before any model is created —
  /// so each shot is fully deterministic: no sign-in, no network, no permission
  /// prompts, no live-poller races.
  ///
  /// Pages: `home` | `stations` | `library` | `player` | `player-tap`
  @MainActor
  struct ScreenshotHarness: View {
    static var requestedPage: String? {
      ProcessInfo.processInfo.environment["SCREENSHOT_PAGE"]
    }

    private let model: MainContainerModel

    // The app body re-evaluates several times during launch; seeding and building in
    // plain init would re-seed shared state and orphan the model instance whose
    // `viewAppeared` already ran, leaving the visible page in its initial empty state.
    private static var cachedModel: MainContainerModel?

    init(page: String) {
      if let cached = Self.cachedModel {
        model = cached
        return
      }
      let fixtures = ScreenshotFixtures(page: page)
      fixtures.seedSharedState()
      // Every sub-model (pollers, coordinators, LikesManager, page models) captures
      // its @Dependency values at init, so constructing MainContainerModel inside
      // this scope routes the whole app through the fixture API.
      let built = withDependencies {
        $0.api = fixtures.apiClient()
        $0.analytics = .noop
        $0.appRating.shouldShowRatingPrompt = { _ in false }
      } operation: {
        let model = MainContainerModel()
        fixtures.presentPlayerSheetIfNeeded()
        return model
      }
      Self.cachedModel = built
      model = built
    }

    var body: some View {
      MainContainer(model: model)
        .preferredColorScheme(.dark)
    }
  }

  // MARK: - Fixtures

  @MainActor
  private struct ScreenshotFixtures {
    let page: String
    let stationLists: IdentifiedArrayOf<StationList>

    init(page: String) {
      self.page = page
      let lists =
        (try? JSONDecoderWithIsoFull().decode(
          [StationList].self, from: Data(Self.stationListsJSON.utf8))) ?? []
      stationLists = IdentifiedArray(uniqueElements: lists)
    }

    // MARK: Page routing

    private var isPlayerPage: Bool { page == "player" || page == "player-tap" }

    private var activeTab: MainContainerModel.ActiveTab {
      switch page {
      case "stations": .stationsList
      case "library": .yourLibrary
      case "profile": .profile
      default: .home
      }
    }

    // MARK: Stations

    private static let recklessStationId = "30f559cb-d0cf-4f5f-a5cd-6039ea7c36e1"

    private var artistStations: [Station] {
      stationLists.first { $0.slug == StationList.artistListSlug }?.playolaStations ?? []
    }

    private func station(withId id: String) -> Station? {
      artistStations.first { $0.id == id }
    }

    private func station(curatedBy curatorName: String) -> Station? {
      artistStations.first { $0.curatorName == curatorName }
    }

    private var liveStationsFixture: [LiveStationInfo] {
      var infos: [LiveStationInfo] = []
      if let reckless = station(withId: Self.recklessStationId) {
        infos.append(
          LiveStationInfo(
            stationId: reckless.id, liveStatus: .voicetracking, station: reckless))
      }
      if let backPorch = station(curatedBy: "Jason Eady") {
        infos.append(
          LiveStationInfo(
            stationId: backPorch.id, liveStatus: .showAiring, station: backPorch))
      }
      return infos
    }

    // MARK: Giveaways

    private static let prizeName = "Two tickets to Reckless Kelly at the Heights"

    private var scheduledGiveaway: GiveawayEvent {
      GiveawayEvent(
        id: "screenshot-giveaway-scheduled",
        stationId: Self.recklessStationId,
        prizeName: Self.prizeName,
        winningNumber: 8,
        status: .scheduled,
        giveawayId: "screenshot-giveaway",
        opensAt: Date().addingTimeInterval(45 * 60))
    }

    private var openGiveaway: GiveawayEvent {
      GiveawayEvent(
        id: "screenshot-giveaway-open",
        stationId: Self.recklessStationId,
        prizeName: Self.prizeName,
        winningNumber: 8,
        status: .open,
        giveawayId: "screenshot-giveaway",
        opensAt: Date().addingTimeInterval(-30),
        serverTime: Date(),
        viewer: GiveawayEventViewer())
    }

    /// The tap shot runs an open contest; home/stations show the "coming up" badge
    /// via a scheduled one; the plain player shot stays clean.
    private var giveawayFeedFixture: [GiveawayEvent] {
      switch page {
      case "player-tap": [openGiveaway]
      case "player": []
      default: [scheduledGiveaway]
      }
    }

    // MARK: Now playing (player pages)

    private static let whyIChoseThisSong = """
      I just haven't talked enough about my buddies in Silverada — they're gonna be up \
      there at the reunion this year. They got Roger Clyne's old bus — it's got a really \
      cool design on the outside, looks like a Navajo rug to me. It's a great bus. \
      Anyway, this is our pal Silverada — Smoke 'Em If You Got 'Em. We'll see you at the \
      Braun Brothers Reunion, y'all.
      """

    private static let nowPlayingSong = SongFixture(
      id: "84f0ff18-6ca5-4e91-8e77-81ab41b16531",
      title: "Smoke 'em If You Got 'em",
      artist: "Silverada",
      album: "Mockingbird",
      durationMS: 227_486,
      imageUrl: "https://i.scdn.co/image/ab67616d0000b273c842d1c6de8196e1a971fea6")

    private var nowPlayingSpin: Spin {
      Spin(
        id: "screenshot-spin",
        stationId: Self.recklessStationId,
        airtime: Date().addingTimeInterval(-60),
        startingVolume: 1.0,
        createdAt: Date(),
        updatedAt: Date(),
        audioBlock: Self.audioBlock(
          for: Self.nowPlayingSong, transcription: Self.whyIChoseThisSong),
        fades: [])
    }

    /// The tap-contest shot airs the artist live, so now playing reads just
    /// "Reckless Kelly" (non-song audio block + airing → episode-title path in
    /// `PlayerPageModel.nowPlayingText`) instead of a song line.
    private func liveShowSpin(for station: Station) -> Spin {
      let episode = Episode(
        id: "screenshot-episode",
        showId: "screenshot-show",
        title: station.curatorName,
        durationMS: 3_600_000,
        createdAt: Date(),
        updatedAt: Date())
      let airing = Airing(
        id: "screenshot-airing",
        episodeId: episode.id,
        stationId: station.id,
        airtime: Date().addingTimeInterval(-15 * 60),
        createdAt: Date(),
        updatedAt: Date(),
        episode: episode)
      let voicetrack = AudioBlock(
        id: "screenshot-live-voicetrack",
        title: station.curatorName,
        artist: station.curatorName,
        durationMS: 60_000,
        endOfMessageMS: 60_000,
        beginningOfOutroMS: 50_000,
        endOfIntroMS: 5_000,
        lengthOfOutroMS: 10_000,
        downloadUrl: nil,
        s3Key: "",
        s3BucketName: "",
        type: "voicetrack",
        createdAt: Date(),
        updatedAt: Date(),
        album: nil,
        popularity: nil,
        youTubeId: nil,
        isrc: nil,
        spotifyId: nil,
        imageUrl: station.imageUrl,
        transcription: nil)
      return Spin(
        id: "screenshot-live-spin",
        stationId: station.id,
        airtime: Date().addingTimeInterval(-15),
        startingVolume: 1.0,
        createdAt: Date(),
        updatedAt: Date(),
        audioBlock: voicetrack,
        fades: [],
        airing: airing)
    }

    private var nowPlayingFixture: NowPlaying? {
      guard isPlayerPage, let reckless = station(withId: Self.recklessStationId) else {
        return nil
      }
      let spin = page == "player-tap" ? liveShowSpin(for: reckless) : nowPlayingSpin
      let station = AnyStation.playola(reckless)
      return NowPlaying(
        artistPlaying: spin.audioBlock.artist,
        titlePlaying: spin.audioBlock.title,
        albumArtworkUrl: spin.audioBlock.imageUrl,
        playolaSpinPlaying: spin,
        currentStation: station,
        playbackStatus: .playing(station))
    }

    // MARK: Liked songs (Your Library)

    private struct SongFixture {
      let id: String
      let title: String
      let artist: String
      let album: String
      let durationMS: Int
      let imageUrl: String
    }

    // Real catalog songs by Playola artists, newest like first.
    // swiftlint:disable line_length
    private static let likedSongs: [SongFixture] = [
      nowPlayingSong,
      SongFixture(
        id: "6d5ce843-3871-4eab-8736-7e7283313a63",
        title: "Old Fashioned", artist: "William Clark Green", album: "Ringling Road",
        durationMS: 231_424,
        imageUrl:
          "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/8a/52/21/8a52216d-9932-43e3-d0f6-e41c7faf9f0f/886445117806_WCGRinglingRoadDigitalCover.jpg/300x300bb.jpg"
      ),
      SongFixture(
        id: "3123e841-0c3a-4cd1-b258-f6a7e9313dd3",
        title: "South Texas Girl", artist: "Jamie Lin Wilson", album: "South Texas Girl",
        durationMS: 334_453,
        imageUrl: "https://i.scdn.co/image/ab67616d0000b2732f101fef8fbbd6e15a353280"
      ),
      SongFixture(
        id: "ac34b708-affa-410e-ae60-e6b42fe6cb34",
        title: "Risky Women", artist: "Jason Eady", album: "Tulsa Turnaround",
        durationMS: 250_915,
        imageUrl:
          "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/54/0f/40/540f405b-dc52-3c8f-887d-ea6744963c25/artwork.jpg/300x300bb.jpg"
      ),
      SongFixture(
        id: "495e4eca-d28f-4ff7-99a5-b0d70b4029b0",
        title: "No Place Like Home", artist: "Bri Bagwell", album: "Banned from Santa Fe",
        durationMS: 264_960,
        imageUrl:
          "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/c5/38/32/c53832d2-c756-78c7-ccad-96a39e08c381/677937684605.jpg/300x300bb.jpg"
      ),
      SongFixture(
        id: "28d361ef-90c6-42a9-9f3c-5679d0715888",
        title: "How the Light Knows", artist: "Shinyribs", album: "Late Night TV Gold",
        durationMS: 334_541,
        imageUrl:
          "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e4/f4/bf/e4f4bf16-41c6-185a-ffc9-386ba5cef7ee/859719131655_cover.jpg/300x300bb.jpg"
      ),
      SongFixture(
        id: "21dda07e-a7d6-40d2-8c45-be36b06606fe",
        title: "Bad Days Better", artist: "Adam Hood", album: "Bad Days Better",
        durationMS: 166_693,
        imageUrl: "https://i.scdn.co/image/ab67616d0000b2731609bed030008420b815d7e0"
      ),
      SongFixture(
        id: "29f5ec6a-361d-45b2-9919-2bff15606868",
        title: "Drag", artist: "Silverada", album: "Living Proof",
        durationMS: 249_347,
        imageUrl:
          "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/da/a3/5a/daa35a49-23cc-e466-abfe-df58fd49c698/820233171267.jpg/300x300bb.jpg"
      ),
      SongFixture(
        id: "a168eb7b-3684-4e6b-8448-2cb952b58014",
        title: "Riding With Private Malone", artist: "Radney Foster",
        album: "Amerikinda: 20 Years of Dualtone",
        durationMS: 279_648,
        imageUrl:
          "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/cc/4c/08/cc4c08cf-f0ca-8e61-49b1-1e0935ef96f5/18658.jpg/300x300bb.jpg"
      ),
    ]
    // swiftlint:enable line_length

    private static let userId = "screenshot-user"

    private static func audioBlock(
      for song: SongFixture, transcription: String? = nil
    ) -> AudioBlock {
      AudioBlock(
        id: song.id,
        title: song.title,
        artist: song.artist,
        durationMS: song.durationMS,
        endOfMessageMS: song.durationMS,
        beginningOfOutroMS: max(0, song.durationMS - 10_000),
        endOfIntroMS: 10_000,
        lengthOfOutroMS: 10_000,
        downloadUrl: nil,
        s3Key: "",
        s3BucketName: "",
        type: "song",
        createdAt: Date(),
        updatedAt: Date(),
        album: song.album,
        popularity: nil,
        youTubeId: nil,
        isrc: nil,
        spotifyId: nil,
        imageUrl: URL(string: song.imageUrl),
        transcription: transcription)
    }

    private var likesFixture: [UserSongLike] {
      Self.likedSongs.enumerated().map { index, song in
        UserSongLike(
          userId: Self.userId,
          audioBlockId: song.id,
          audioBlock: Self.audioBlock(for: song),
          createdAt: Date().addingTimeInterval(TimeInterval(-3600 * (index + 1))))
      }
    }

    // MARK: Presets

    private var presetsFixture: IdentifiedArrayOf<Preset> {
      let curators = ["Reckless Kelly", "William Clark Green", "Jamie Lin Wilson", "Shinyribs"]
      let presets = curators.enumerated().compactMap { index, curator -> Preset? in
        guard let station = station(curatedBy: curator) else { return nil }
        return Preset(
          id: "screenshot-preset-\(index)",
          userId: Self.userId,
          stationId: station.id,
          urlStationId: nil,
          position: index,
          createdAt: Date(),
          updatedAt: Date(),
          station: PresetStation(
            id: station.id, name: station.name, imageUrl: station.imageUrl?.absoluteString),
          urlStation: nil)
      }
      return IdentifiedArray(uniqueElements: presets)
    }

    // MARK: Seeding

    func seedSharedState() {
      @Shared(.auth) var auth
      $auth.withLock {
        $0 = Auth(
          loggedInUser: LoggedInUser(
            id: Self.userId, firstName: "Brian", email: "screenshots@playola.fm"))
      }

      @Shared(.hasAskedForNotificationPermission) var hasAskedForNotificationPermission
      $hasAskedForNotificationPermission.withLock { $0 = true }

      @Shared(.activeTab) var tab
      $tab.withLock { $0 = activeTab }

      @Shared(.stationLists) var lists
      $lists.withLock { $0 = stationLists }
      @Shared(.stationListsLoaded) var stationListsLoaded
      $stationListsLoaded.withLock { $0 = true }

      @Shared(.userLikes) var userLikes
      $userLikes.withLock { likes in
        likes = Dictionary(
          uniqueKeysWithValues: likesFixture.map { ($0.audioBlockId, $0) })
      }
      @Shared(.pendingLikeOperations) var pendingLikeOperations
      $pendingLikeOperations.withLock { $0 = [] }

      @Shared(.presets) var presets
      $presets.withLock { $0 = presetsFixture }

      @Shared(.liveStations) var liveStations
      $liveStations.withLock { $0 = liveStationsFixture }

      @Shared(.upcomingGiveaways) var upcomingGiveaways
      $upcomingGiveaways.withLock {
        $0 = IdentifiedArray(
          uniqueElements:
            giveawayFeedFixture
            .filter { $0.status == .scheduled }
            .map(UpcomingGiveawayInfo.init(event:)))
      }

      // The sim may carry real persisted state from earlier runs; clear anything that
      // could pop a winner sheet, toast, or banner mid-shot.
      @Shared(.giveawayParticipations) var giveawayParticipations
      $giveawayParticipations.withLock { $0 = [:] }
      @Shared(.pendingCongratsActions) var pendingCongratsActions
      $pendingCongratsActions.withLock { $0 = [:] }
      @Shared(.dismissedGiveawayBannerIds) var dismissedGiveawayBannerIds
      $dismissedGiveawayBannerIds.withLock { $0 = [] }

      if let nowPlaying = nowPlayingFixture {
        @Shared(.nowPlaying) var sharedNowPlaying
        $sharedNowPlaying.withLock { $0 = nowPlaying }
      }
      if page == "player-tap" {
        @Shared(.activeGiveaway) var activeGiveaway
        $activeGiveaway.withLock { $0 = openGiveaway }
      }
    }

    func presentPlayerSheetIfNeeded() {
      guard isPlayerPage else { return }
      @Shared(.mainContainerNavigationCoordinator) var coordinator
      coordinator.presentedSheet = .player(PlayerPageModel())
    }

    // MARK: Fixture API client

    /// Every endpoint the launch sequence touches answers from the fixtures above, so
    /// pollers and sync passes can only ever rewrite the same seeded state.
    func apiClient() -> APIClient {
      var api = APIClient()
      let lists = stationLists
      api.getStations = { lists }
      let live = liveStationsFixture
      api.fetchLiveStations = { _ in live }
      let feed = giveawayFeedFixture
      api.giveawayEventsFeed = { _ in feed }
      let open = openGiveaway
      api.giveawayEvent = { _, _ in open }
      if page == "player-tap" {
        api.activeGiveawayEvent = { _, _ in open }
      }
      api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 45_240_000,
          totalMSAvailableForRewards: 45_240_000,
          accurateAsOfTime: Date())
      }
      let presets = Array(presetsFixture)
      api.getPresets = { _ in presets }
      let likes = likesFixture
      api.getLikedSongs = { _ in likes }
      return api
    }

    // MARK: Station data

    // Real production `/v1/station-lists` payload (captured 2026-08-27), stripped to
    // the keys the app decodes. Embedded so the shots never depend on the network.
    // swiftlint:disable line_length
    private static let stationListsJSON = #"""
      [{"id":"9e41ae6b-d844-48b4-8f4e-7d0aa0f88ac0","name":"Artist Stations","slug":"artist-list","hidden":false,"sortOrder":0,"createdAt":"2025-09-11T20:09:03.972Z","updatedAt":"2025-09-11T20:09:03.972Z","items":[{"sortOrder":0,"visibility":"visible","station":{"id":"06cdc91a-eb7b-490e-bafb-873df63b1415","name":"8750 Radio","curatorName":"8750 Festival Artists","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/8750 festival-172655.jpeg","description":"Disappears 9/1 -- See you next year!","active":true,"releaseDate":"2026-05-28","createdAt":"2026-05-08T01:02:55.982Z","updatedAt":"2026-08-20T14:28:37.059Z"},"urlStation":null},{"sortOrder":1,"visibility":"visible","station":{"id":"18b1ff07-9f3c-412a-a4d7-4fe82a5dd523","name":"Bordertown Radio","curatorName":"Radney Foster","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Rad blue wall hi rez-544064.png","description":"","active":true,"releaseDate":"2026-06-03","createdAt":"2026-04-01T21:42:03.266Z","updatedAt":"2026-06-07T14:52:51.521Z"},"urlStation":null},{"sortOrder":2,"visibility":"visible","station":{"id":"2aa776b4-0b3a-4111-836b-97e58e6829b4","name":"Ring Radio","curatorName":"Bart Crow","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/bart crow station image-749576.jpeg","description":"","active":true,"releaseDate":"2026-04-21","createdAt":"2026-04-01T21:25:52.527Z","updatedAt":"2026-08-07T19:39:09.599Z"},"urlStation":null},{"sortOrder":3,"visibility":"visible","station":{"id":"7dd37d26-fc83-47fe-9eb4-c3e71ee175b0","name":"Bill Grease Radio","curatorName":"William Clark Green","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/WCG station photo-616524.jpg","description":"","active":true,"releaseDate":"2026-04-24","createdAt":"2026-04-01T15:48:20.418Z","updatedAt":"2026-04-25T01:00:04.719Z"},"urlStation":null},{"sortOrder":4,"visibility":"visible","station":{"id":"5055edc1-15ea-4626-bac7-b4136f31db54","name":"Idaho Stars Radio","curatorName":"Micky and the Motorcars","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2025-09-16 at 8.09.34 AM-520244.png","description":"","active":true,"releaseDate":"2026-01-27","createdAt":"2025-10-03T14:25:24.935Z","updatedAt":"2026-07-08T15:17:47.619Z"},"urlStation":null},{"sortOrder":5,"visibility":"visible","station":{"id":"30f559cb-d0cf-4f5f-a5cd-6039ea7c36e1","name":"Reckless Radio","curatorName":"Reckless Kelly","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2026-01-19 at 7.03.36 PM-034992.png","description":"","active":true,"releaseDate":"2026-03-02","createdAt":"2026-01-20T01:04:04.968Z","updatedAt":"2026-07-18T02:54:06.994Z"},"urlStation":null},{"sortOrder":6,"visibility":"visible","station":{"id":"0c8fc802-65cf-496b-ac22-c3fcf8fb1404","name":"Backslide Radio","curatorName":"Ashton Naylor","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2026-01-06 at 1.25.31 PM-551094.png","description":"","active":true,"releaseDate":"2026-02-17","createdAt":"2026-01-06T19:24:31.438Z","updatedAt":"2026-06-07T14:51:38.355Z"},"urlStation":null},{"sortOrder":7,"visibility":"visible","station":{"id":"dadb988c-bdf6-47c3-b5f4-c25bda25fb91","name":"Spark Radio","curatorName":"Hank Weaver","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2025-12-31 at 12.39.08 PM-365117.png","description":"","active":true,"releaseDate":"2026-02-17","createdAt":"2025-12-31T18:39:28.234Z","updatedAt":"2026-04-06T18:00:08.836Z"},"urlStation":null},{"sortOrder":8,"visibility":"visible","station":{"id":"7d464dee-b967-4767-a114-c99d933eeff7","name":"Downpour Radio","curatorName":"Larissa Boyd","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2025-11-19 at 10.00.33 AM-065606.png","description":"","active":true,"releaseDate":"2026-01-27","createdAt":"2025-11-04T18:06:21.639Z","updatedAt":"2026-06-07T14:52:49.155Z"},"urlStation":null},{"sortOrder":9,"visibility":"visible","station":{"id":"1d0a499a-76dd-4d3d-b9b8-504717c25ed9","name":"Shutters and Rings Radio","curatorName":"Suzanna Choffel","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/S-Choffel-Daniel-CavazosB&W-152669.jpg","description":"","active":true,"releaseDate":"2026-01-13","createdAt":"2025-09-02T19:55:54.232Z","updatedAt":"2026-04-16T16:44:48.113Z"},"urlStation":null},{"sortOrder":10,"visibility":"visible","station":{"id":"dc9a5cd2-3e6b-472e-848b-00010c87f06e","name":"Southern Songs Radio","curatorName":"Adam Hood","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/adamHoodBig-703483.jpg","description":"","active":true,"releaseDate":"2025-12-30","createdAt":"2025-11-04T19:50:27.078Z","updatedAt":"2026-04-06T18:00:27.811Z"},"urlStation":null},{"sortOrder":11,"visibility":"visible","station":{"id":"3c5d98c9-59d0-42b6-8f60-4f93ea5c5dff","name":"Simple Enough Radio","curatorName":"Jamie Lin Wilson","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/241709008_873078870018683_5083831661921892201_n-423704.jpg","description":"","active":true,"releaseDate":"2025-12-23","createdAt":"2025-11-04T19:50:11.174Z","updatedAt":"2026-06-07T14:52:36.318Z"},"urlStation":null},{"sortOrder":12,"visibility":"visible","station":{"id":"d676048c-30af-41e6-a3f6-db54c4fcc177","name":"Love Junkie Radio","curatorName":"Slade Coulter","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/EG-27-255846.jpeg","description":"","active":true,"releaseDate":"2025-12-09","createdAt":"2025-11-04T19:49:11.738Z","updatedAt":"2026-04-06T18:00:13.672Z"},"urlStation":null},{"sortOrder":13,"visibility":"visible","station":{"id":"42d302e8-000f-4b9d-93c6-3fbcb35ff43b","name":"East Texas Rust Radio","curatorName":"Shinyribs","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/IMG_0910-948133.jpg","description":"","active":true,"releaseDate":"2025-12-16","createdAt":"2025-09-18T15:55:51.748Z","updatedAt":"2026-04-06T18:00:06.242Z"},"urlStation":null},{"sortOrder":14,"visibility":"visible","station":{"id":"53472e53-c641-48e5-a372-656f05e1aaa6","name":"Something More Radio","curatorName":"Cory Morrow","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/cory morrow photo-524399.webp","description":"This is all music that makes me feel good: classic country, classic rock, new Texas country, and contemporary gospel.","active":true,"releaseDate":"2025-11-25","createdAt":"2025-08-12T17:42:09.193Z","updatedAt":"2026-04-06T18:00:11.099Z"},"urlStation":null},{"sortOrder":15,"visibility":"visible","station":{"id":"f3864734-de35-414f-b0b3-e6909b0b77bd","name":"Banned Radio","curatorName":"Bri Bagwell","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/briBagwell-695143.jpg","description":"I love country music: Texas country, classic country, and a few hand-picked Nashville gems.","active":true,"releaseDate":null,"createdAt":"2024-09-24T23:43:58.850Z","updatedAt":"2026-08-07T19:40:08.199Z"},"urlStation":null},{"sortOrder":16,"visibility":"visible","station":{"id":"9d79fd38-1940-4312-8fe8-3b9b50d49c6c","name":"Moondog Radio","curatorName":"Jacob Stelly","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Jacob-Stelly-1-116029.jpg","description":"My band and I love alternative rock, Texas country, alternative pop, and classic country.","active":true,"releaseDate":null,"createdAt":"2025-03-09T16:57:16.762Z","updatedAt":"2026-07-13T23:53:06.300Z"},"urlStation":null},{"sortOrder":17,"visibility":"visible","station":{"id":"9c387fd6-5197-4daa-8529-bf7fbe286aba","name":"Melt Radio","curatorName":"Mila","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/mila_3-768747.jpg","description":"Check out my collection of alternative pop, underground country and current hits that I love.","active":true,"releaseDate":null,"createdAt":"2025-03-09T17:01:10.291Z","updatedAt":"2026-04-06T18:00:47.680Z"},"urlStation":null},{"sortOrder":18,"visibility":"visible","station":{"id":"5a001e4c-da9e-46c1-911d-26c6ea69b346","name":"Bluebird Radio","curatorName":"Jordan Nix","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/jordan_nix-656485.jpg","description":"Jordan Nix spins his favorite songs.","active":true,"releaseDate":null,"createdAt":"2025-03-27T18:52:09.640Z","updatedAt":"2026-04-06T18:00:25.446Z"},"urlStation":null},{"sortOrder":19,"visibility":"visible","station":{"id":"55c01713-7f42-4b97-8bb3-669bdcaaa859","name":"Red River Radio","curatorName":"Gatlin Johnson","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2025-12-31 at 12.41.09 PM-479455.png","description":"","active":true,"releaseDate":"2026-03-03","createdAt":"2025-12-31T18:40:11.741Z","updatedAt":"2026-06-19T15:44:48.423Z"},"urlStation":null},{"sortOrder":20,"visibility":"visible","station":{"id":"95dfebe9-16ab-4827-aae1-da32e32c00c1","name":"Back Porch Radio","curatorName":"Jason Eady","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/Screenshot 2025-09-30 at 7.41.23 AM-016719.png","description":"Hey y'all, here is some classic, groovy, honest Americana roots music from Texas, Mississippi, Louisiana, and Tennessee.","active":true,"releaseDate":"2025-12-02","createdAt":"2025-11-04T18:05:13.299Z","updatedAt":"2026-04-06T18:00:17.722Z"},"urlStation":null}]},{"id":"49699a55-848b-4b8a-b062-62b55b9a111d","name":"FM Stations","slug":"fm-stations","hidden":false,"sortOrder":10,"createdAt":"2025-09-12T17:23:48.416Z","updatedAt":"2025-09-12T17:23:48.416Z","items":[{"sortOrder":0,"visibility":"visible","station":null,"urlStation":{"id":"1415df86-e514-4620-934d-3558d5c0fabe","name":"Red Dirt Rebel - 107.7","streamUrl":"https://das-edge53-sa48-futuri-dal03.cdnstream.com/7940_96k.aac","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/reddirtrebel-101518.jpeg","description":"","website":"https://www.1077thereddirtrebel.com/","location":"Lubbock, TX","active":true,"createdAt":"2026-04-09T18:43:23.894Z","updatedAt":"2026-04-09T18:43:23.894Z"}},{"sortOrder":1,"visibility":"visible","station":null,"urlStation":{"id":"a7054261-1bf2-49f6-bf2f-e662f6d81607","name":"95.7 KPUR FM","streamUrl":"https://22963.live.streamtheworld.com/KPURFMAAC.aac","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/kpur_95_7_logo-410161.png","description":"Amarillo's Country Music Station","website":"https://www.957kpur.com/","location":"Amarillo, TX","active":true,"createdAt":"2025-09-12T14:13:33.596Z","updatedAt":"2025-09-12T14:13:33.596Z"}},{"sortOrder":2,"visibility":"visible","station":null,"urlStation":{"id":"373ac74c-2c38-4ca4-8fb1-d191674d8639","name":"KOKE FM","streamUrl":"https://arn.leanstream.co/KOKEFM-MP3","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/koke-fm-logo-809362.png","description":"KOKE FM is an Austin, Texas based alternative country station. \"Country Without Apology\".","website":"https://kokefm.com/","location":"Austin, TX","active":true,"createdAt":"2025-09-11T21:40:19.177Z","updatedAt":"2025-09-11T21:40:19.177Z"}},{"sortOrder":3,"visibility":"visible","station":null,"urlStation":{"id":"0c2fb261-d4f3-4e26-8bf0-503d12727ab2","name":"Lakes Country 102.1","streamUrl":"https://18863.live.streamtheworld.com/KEOKFMAAC.aac","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/102_1_keok-962920.png","description":"Lakes Country 102.1 provides today's best country (including Red Dirt & Local Music) along with community information, news & sports!","website":"https://www.lakescountry1021.com/","location":"Tahlequah, OK","active":true,"createdAt":"2025-09-11T21:43:22.144Z","updatedAt":"2025-09-11T21:43:22.144Z"}},{"sortOrder":4,"visibility":"visible","station":null,"urlStation":{"id":"3f607393-ba40-4690-b304-0535a8006f80","name":"97.5 KFTX","streamUrl":"https://ice7.securenetsystems.net/KFTX\"","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/kftx_logo-111911.png","description":"KFTX.com is your 24 hour a day connection to yesterday's & today's REAL COUNTRY HITS and all your favorites!","website":"https://www.kftx.com/","location":"Corpus Christi, TX","active":true,"createdAt":"2025-09-11T21:45:17.107Z","updatedAt":"2025-09-11T21:45:17.107Z"}},{"sortOrder":5,"visibility":"visible","station":null,"urlStation":{"id":"c982c9d0-9dcf-4ab8-8295-18af4c30010c","name":"105.5 KGFY - Cowboy Country","streamUrl":"https://ice24.securenetsystems.net/KGFY","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/kgfy_logo-378908.png","description":"We play the hottest country music from Carrie Underwood, Keith Urban, Luke Bryan, Jason Aldean, Kenny Chesney to Miranda Lambert. Playing the best in Red Dirt from Aaron Watson, The Randy Rogers Band, The Turnpike Troubadours, Josh Abbott, and The Casey Donahew Band; plus so much more. Besides playing the best in country music, Cowboy Country 105.5 is also the voice of OSU Cowgirl Sports and Perkins Tryon High School sports. Stillwater knows country music. Hear it on KGFY Cowboy Country 105.5!","website":"https://stillwaterradio.net/kgfy-fm/kgfy-fm-line-up","location":"Stillwater, OK","active":true,"createdAt":"2025-09-11T21:49:41.453Z","updatedAt":"2025-09-11T21:49:41.453Z"}},{"sortOrder":6,"visibility":"visible","station":null,"urlStation":{"id":"7d41666f-5700-4f9f-b1fd-29ffcb94ddf4","name":"KNES Texas 99.1 FM","streamUrl":"https://ice5.securenetsystems.net/KNES","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/knes_991_logo-143694.jpg","description":"We're Taking Country Back","website":"https://www.texas99.com/","location":"Fairfield, TX","active":true,"createdAt":"2025-09-12T14:09:09.514Z","updatedAt":"2025-09-12T14:09:09.514Z"}},{"sortOrder":7,"visibility":"visible","station":null,"urlStation":{"id":"d1308a9f-dbd6-4703-91e0-04af6966361b","name":"KRUN 1400 AM","streamUrl":"https://stream-01.aiir.com/2f0egozmjmetv","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/krun_1400am_logo-312542.jpg","description":"The #1 radio station in Northeast Texas and Southeastern Oklahoma.","website":"http://www.krunam.com/","location":"Ballinger, TX","active":true,"createdAt":"2025-09-12T14:11:57.988Z","updatedAt":"2025-09-12T14:11:57.988Z"}},{"sortOrder":8,"visibility":"visible","station":null,"urlStation":{"id":"ac15a15e-51c3-4963-95e4-9018c954408a","name":"KSEL Country 105.9 FM","streamUrl":"https://streaming.live365.com/a44766","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/ksel_105_9_logo-495320.png","description":"Your Kinda Country","website":"https://kselcountry.com/","location":"Portales, NM","active":true,"createdAt":"2025-09-12T14:15:55.669Z","updatedAt":"2025-09-12T14:15:55.669Z"}},{"sortOrder":9,"visibility":"visible","station":null,"urlStation":{"id":"7ce9d8e6-b302-4d0f-8179-fbf55db5ff6a","name":"Red Dirt 96.7 - The Kage","streamUrl":"https://ice41.securenetsystems.net/KAGE","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/96_7_kxrd_logo-979321.png","description":"Red Dirt Country","website":"https://www.reddirtnwa.com/","location":"Fayetteville, AR","active":true,"createdAt":"2025-09-12T14:23:03.876Z","updatedAt":"2025-09-12T14:23:03.876Z"}},{"sortOrder":10,"visibility":"visible","station":null,"urlStation":{"id":"778f2fba-b2bb-423e-a580-bdef63393d2e","name":"KNON Texas Renegade Radio","streamUrl":"https://s11.citrus3.com:8202/stream","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/KNONlogoWhite-836114.jpg","description":"KNON is a non-profit, listener-supported community radio station, deriving its main source of income from on-air pledge drives and from underwriting or sponsorships by local small businesses.","website":"https://www.knon.org/","location":"Dallas","active":true,"createdAt":"2025-12-18T18:00:40.998Z","updatedAt":"2025-12-18T18:00:40.998Z"}},{"sortOrder":11,"visibility":"visible","station":null,"urlStation":{"id":"c76bd388-8012-4a7f-9de9-2ec72ebbd6fa","name":"Texas Thunder Radio 94.3","streamUrl":"http://ice5.securenetsystems.net/KYKM","imageUrl":"https://playola-static.s3.amazonaws.com/station-images/94_3_kykm_logo-053237.jpg","description":"Texas Thunder Radio","website":"https://txthunderradio.com/","location":"Yoakum, TX","active":true,"createdAt":"2025-09-12T14:24:15.425Z","updatedAt":"2025-09-12T14:24:15.425Z"}}]}]
      """#
    // swiftlint:enable line_length
  }
#endif
