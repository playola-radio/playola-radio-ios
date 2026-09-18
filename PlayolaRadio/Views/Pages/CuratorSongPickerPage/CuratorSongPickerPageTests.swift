//
//  CuratorSongPickerPageTests.swift
//  PlayolaRadio
//

import Clocks
import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct CuratorSongPickerPageTests {

  // MARK: - Helpers

  private nonisolated func audioBlock(
    id: String,
    title: String = "Song",
    artist: String = "Artist",
    appleId: String? = nil,
    isrc: String? = nil,
    spotifyId: String? = nil,
    durationMS: Int = 200_000
  ) -> AudioBlock {
    let base = AudioBlock.mockWith(
      id: id, title: title, artist: artist, durationMS: durationMS,
      downloadUrl: URL(string: "https://example.com/\(id).mp3"))
    return AudioBlock(
      id: base.id, title: base.title, artist: base.artist, durationMS: base.durationMS,
      endOfMessageMS: base.endOfMessageMS, beginningOfOutroMS: base.beginningOfOutroMS,
      endOfIntroMS: base.endOfIntroMS, lengthOfOutroMS: base.lengthOfOutroMS,
      downloadUrl: base.downloadUrl, s3Key: base.s3Key, s3BucketName: base.s3BucketName,
      type: base.type, createdAt: base.createdAt, updatedAt: base.updatedAt, album: base.album,
      popularity: base.popularity, youTubeId: base.youTubeId, isrc: isrc, spotifyId: spotifyId,
      appleId: appleId, imageUrl: base.imageUrl, transcription: base.transcription)
  }

  private nonisolated func songRequest(
    title: String = "Song",
    artist: String = "Artist",
    appleId: String = "apple-req",
    isrc: String? = nil,
    spotifyId: String? = nil
  ) -> SongRequest {
    SongRequest.mockWith(
      title: title, artist: artist, isrc: isrc, appleId: appleId, spotifyId: spotifyId)
  }

  private nonisolated func suggestion(_ block: AudioBlock) -> SongSuggestion {
    SongSuggestion(audioBlock: block)
  }

  // MARK: - Init

  @Test func initSeedsAddedSongIds() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(
        stationId: "station-1", initialAddedSongIds: ["song-1", "song-2"])

      #expect(model.addedSongIds == ["song-1", "song-2"])
      #expect(model.isAdded(audioBlock(id: "song-1")))
      #expect(!model.isAdded(audioBlock(id: "song-3")))
    }
  }

  // MARK: - Dedup

  @Test func dedupMatchesByAppleId() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [audioBlock(id: "b1", appleId: "APPLE-1")]
      model.songRequestResults = [
        songRequest(appleId: "APPLE-1"),
        songRequest(appleId: "APPLE-2"),
      ]

      #expect(model.dedupedRequests.map(\.appleId) == ["APPLE-2"])
    }
  }

  @Test func dedupMatchesByIsrcWhenAppleIdAbsentOnLibrarySide() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [audioBlock(id: "b1", appleId: nil, isrc: "ISRC-1")]
      model.songRequestResults = [
        songRequest(appleId: "req-a", isrc: "ISRC-1"),
        songRequest(appleId: "req-b", isrc: "ISRC-2"),
      ]

      #expect(model.dedupedRequests.map(\.appleId) == ["req-b"])
    }
  }

  @Test func dedupMatchesBySpotifyIdWhenAppleAndIsrcAbsent() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [audioBlock(id: "b1", appleId: nil, isrc: nil, spotifyId: "SPOT-1")]
      model.songRequestResults = [
        songRequest(appleId: "req-a", isrc: nil, spotifyId: "SPOT-1"),
        songRequest(appleId: "req-b", isrc: nil, spotifyId: "SPOT-2"),
      ]

      #expect(model.dedupedRequests.map(\.appleId) == ["req-b"])
    }
  }

  @Test func dedupMatchesByNormalizedTitleAndArtist() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [
        audioBlock(id: "b1", title: "  Hey Jude ", artist: "THE BEATLES")
      ]
      model.songRequestResults = [
        songRequest(title: "hey jude", artist: "the beatles", appleId: "req-a"),
        songRequest(title: "Let It Be", artist: "The Beatles", appleId: "req-b"),
      ]

      #expect(model.dedupedRequests.map(\.appleId) == ["req-b"])
    }
  }

  @Test func dedupNeverMatchesOnTwoNilIdentifiers() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [
        audioBlock(
          id: "b1", title: "Library Song", artist: "Library Artist",
          appleId: nil, isrc: nil, spotifyId: nil)
      ]
      model.songRequestResults = [
        songRequest(
          title: "Request Song", artist: "Request Artist",
          appleId: "req-a", isrc: nil, spotifyId: nil)
      ]

      #expect(model.dedupedRequests.map(\.appleId) == ["req-a"])
    }
  }

  @Test func dedupKeepsGenuinelyDifferentSongs() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [
        audioBlock(id: "b1", title: "Song One", artist: "Artist One", appleId: "APPLE-1")
      ]
      model.songRequestResults = [
        songRequest(title: "Song Two", artist: "Artist Two", appleId: "APPLE-2"),
        songRequest(title: "Song Three", artist: "Artist Three", appleId: "APPLE-3"),
      ]

      #expect(model.dedupedRequests.count == 2)
    }
  }

  @Test func dedupDoesNotMatchDifferentAppleIdsEvenWithSharedIsrc() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.searchResults = [audioBlock(id: "b1", appleId: "APPLE-1", isrc: "ISRC-1")]
      model.songRequestResults = [songRequest(appleId: "APPLE-2", isrc: "ISRC-1")]

      #expect(model.dedupedRequests.map(\.appleId) == ["APPLE-2"])
    }
  }

  // MARK: - Search / debounce

  @Test func debounceCollapsesRapidInputToOneSearch() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let searchCount = LockIsolated(0)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          searchCount.withValue { $0 += 1 }
          return []
        }
        $0.api.searchSongRequests = { _, _ in [] }
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "s")

        model.searchText = "B"
        await clock.advance(by: .milliseconds(100))
        model.searchText = "Bo"
        await clock.advance(by: .milliseconds(100))
        model.searchText = "Bob"
        await clock.advance(by: .milliseconds(300))

        #expect(searchCount.value == 1)
      }
    }
  }

  @Test func staleSearchDoesNotOverwriteNewerResults() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, query in
          if query == "slow" {
            try? await clock.sleep(for: .seconds(5))
            return [self.audioBlock(id: "stale")]
          }
          return [self.audioBlock(id: "fresh")]
        }
        $0.api.searchSongRequests = { _, _ in [] }
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "s")

        model.searchText = "slow"
        await clock.advance(by: .milliseconds(300))
        model.searchText = "fast"
        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(5))

        #expect(model.searchResults.map(\.id) == ["fresh"])
      }
    }
  }

  @Test func searchPopulatesResultsAndRequests() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in [self.audioBlock(id: "b1")] }
        $0.api.searchSongRequests = { _, _ in [self.songRequest(appleId: "req-a")] }
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "s")
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        #expect(model.searchResults.map(\.id) == ["b1"])
        #expect(model.songRequestResults.map(\.appleId) == ["req-a"])
        #expect(!model.isSearching)
      }
    }
  }

  @Test func searchWithoutAuthClearsSpinnerLeftByAPriorSearch() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth()

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "s")
        // A prior search put the spinner up; the token then expired (auth.jwt == nil).
        model.isSearching = true
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        #expect(!model.isSearching)
        #expect(model.presentedAlert == .notAuthenticated)
      }
    }
  }

  // MARK: - Tab switching

  @Test func tabSwitchPreservesQueryAndAddedStateAndStopsPreview() async {
    let audioClient = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      })

    await withDependencies {
      $0.continuousClock = TestClock()
      $0.date = .constant(Date())
      $0.audioPlayer = audioClient
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      let block = audioBlock(id: "b1")
      model.searchText = "hello"
      model.addButtonTapped(block)
      await model.previewButtonTapped(block)
      #expect(model.preview.isActive(block))

      await model.tabSelected(.suggestions)

      #expect(model.selectedTab == .suggestions)
      #expect(model.searchText == "hello")
      #expect(model.isAdded(block))
      #expect(!model.preview.isActive(block))
    }
  }

  // MARK: - Add (one-way)

  @Test func addButtonTappedInsertsIdAndCallsCallback() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let added = LockIsolated<[String]>([])
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.onAddSong = { block in added.withValue { $0.append(block.id) } }
      let block = audioBlock(id: "b1")

      model.addButtonTapped(block)

      #expect(model.isAdded(block))
      #expect(added.value == ["b1"])
      expectNoDifference(model.addButtonText(for: block), "Added")
    }
  }

  @Test func addButtonTappedIsOneWay() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let added = LockIsolated<[String]>([])
      let model = CuratorSongPickerPageModel(stationId: "s")
      model.onAddSong = { block in added.withValue { $0.append(block.id) } }
      let block = audioBlock(id: "b1")

      model.addButtonTapped(block)
      model.addButtonTapped(block)

      #expect(added.value == ["b1"])
      #expect(model.isAdded(block))
    }
  }

  // MARK: - Request

  @Test func requestButtonTappedMarksRequested() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, _ in }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "s")
      let request = songRequest(appleId: "req-a")

      await model.requestButtonTapped(request)

      #expect(model.isRequested(request))
      #expect(model.requestedAppleIds.contains("req-a"))
      expectNoDifference(model.requestButtonText(for: request), "Requested")
    }
  }

  @Test func requestButtonTappedGuardsAgainstInFlightDuplicate() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let requestCount = LockIsolated(0)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.requestSong = { _, _ in
          requestCount.withValue { $0 += 1 }
          try? await clock.sleep(for: .seconds(1))
        }
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "s")
        let request = songRequest(appleId: "req-a")

        async let first: Void = model.requestButtonTapped(request)
        async let second: Void = model.requestButtonTapped(request)
        await clock.advance(by: .seconds(1))
        _ = await (first, second)

        #expect(requestCount.value == 1)
        #expect(model.requestedAppleIds == ["req-a"])
      }
    }
  }

  // MARK: - Suggestions

  @Test func suggestionsAppearedLoadsAndWindowsFirstPage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let blocks = (0..<25).map { suggestion(audioBlock(id: "s\($0)")) }

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in blocks }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")

      await model.suggestionsAppeared()

      #expect(model.suggestions.count == 25)
      #expect(model.visibleSuggestions.count == 20)
      #expect(model.canLoadMoreSuggestions)
      #expect(!model.suggestionsExhausted)
      #expect(!model.isLoadingSuggestions)
    }
  }

  @Test func moreSuggestionsAppendsWithoutResettingAddedState() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let blocks = (0..<25).map { suggestion(audioBlock(id: "s\($0)")) }

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in blocks }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")
      await model.suggestionsAppeared()
      model.addButtonTapped(audioBlock(id: "s0"))

      model.moreSuggestionsTapped()

      #expect(model.visibleSuggestions.count == 25)
      #expect(model.suggestionsExhausted)
      #expect(!model.canLoadMoreSuggestions)
      #expect(model.isAdded(audioBlock(id: "s0")))
    }
  }

  @Test func suggestionsAppearedLoadsOnlyOnce() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let loadCount = LockIsolated(0)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in
        loadCount.withValue { $0 += 1 }
        return [self.suggestion(self.audioBlock(id: "s0"))]
      }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")

      await model.suggestionsAppeared()
      await model.suggestionsAppeared()

      #expect(loadCount.value == 1)
    }
  }

  @Test func suggestionsFailureRetainsFailureThenRetrySucceeds() async {
    struct SuggestionError: Error {}
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let shouldFail = LockIsolated(true)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in
        if shouldFail.value { throw SuggestionError() }
        return [self.suggestion(self.audioBlock(id: "s0"))]
      }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")

      await model.suggestionsAppeared()
      #expect(model.suggestionsFailed)
      #expect(model.suggestions.isEmpty)
      #expect(!model.isLoadingSuggestions)

      shouldFail.setValue(false)
      await model.retrySuggestionsTapped()

      #expect(!model.suggestionsFailed)
      #expect(model.suggestions.count == 1)
    }
  }

  @Test func selectedTabAppearedLoadsOnlyWhenSuggestionsTabActive() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let loadCount = LockIsolated(0)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in
        loadCount.withValue { $0 += 1 }
        return [self.suggestion(self.audioBlock(id: "s0"))]
      }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")

      await model.selectedTabAppeared()
      #expect(loadCount.value == 0)

      await model.tabSelected(.suggestions)
      await model.selectedTabAppeared()
      #expect(loadCount.value == 1)
    }
  }

  @Test func emptySuggestionsShowExhaustedMessageNotBlankTab() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in [] }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")

      await model.suggestionsAppeared()

      #expect(model.suggestions.isEmpty)
      #expect(!model.isLoadingSuggestions)
      #expect(!model.suggestionsFailed)
      #expect(model.suggestionsExhausted)
      #expect(!model.canLoadMoreSuggestions)
      #expect(model.suggestionsExhaustedMessages.count == 1)
    }
  }

  @Test func suggestionsFetchSurvivesCancellationOfTheAppearanceTask() async {
    // The Suggestions tab loads from the view's `.task(id: selectedTab)`, which SwiftUI cancels
    // when the tab changes. Because the model owns the fetch in its own task, cancelling the
    // awaiting context (simulated here by cancelling the wrapping task) must NOT abort the fetch or
    // flip the tab into its failure state.
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.getSongSuggestions = { _, _ in
          try await clock.sleep(for: .seconds(2))
          if Task.isCancelled { throw CancellationError() }
          return [self.suggestion(self.audioBlock(id: "s0"))]
        }
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "station-1")

        let appearance = Task { await model.suggestionsAppeared() }
        await clock.advance(by: .milliseconds(1))
        appearance.cancel()
        await clock.advance(by: .seconds(2))
        await appearance.value

        #expect(model.suggestions.map(\.id) == ["s0"])
        #expect(!model.suggestionsFailed)
        #expect(!model.isLoadingSuggestions)
      }
    }
  }

  @Test func requestMatchingLibrarySongIsDedupedRegardlessOfArrivalOrder() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          try? await clock.sleep(for: .seconds(2))
          return [self.audioBlock(id: "b1", appleId: "APPLE-1")]
        }
        $0.api.searchSongRequests = { _, _ in [self.songRequest(appleId: "APPLE-1")] }
      } operation: {
        let model = CuratorSongPickerPageModel(stationId: "s")
        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))

        // Requests resolve first, but nothing is published until the library lookup also returns,
        // so a library song never surfaces as a requestable row mid-flight.
        #expect(model.songRequestResults.isEmpty)
        #expect(model.dedupedRequests.isEmpty)

        await clock.advance(by: .seconds(2))

        #expect(model.searchResults.map(\.id) == ["b1"])
        #expect(model.dedupedRequests.isEmpty)
        #expect(!model.isSearching)
      }
    }
  }

  @Test func suggestionsDedupeById() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let blocks = [
      suggestion(audioBlock(id: "dup")),
      suggestion(audioBlock(id: "dup")),
      suggestion(audioBlock(id: "unique")),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getSongSuggestions = { _, _ in blocks }
    } operation: {
      let model = CuratorSongPickerPageModel(stationId: "station-1")

      await model.suggestionsAppeared()

      #expect(model.suggestions.map(\.id) == ["dup", "unique"])
    }
  }
}
