//
//  UpsideDownNotificationBannerModelTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct UpsideDownNotificationBannerModelTests {
  @Test
  func testShowPresentsBannerWithNotificationText() {
    let model = makeModel()

    expectDifference(model.banner) {
      model.show(title: "New message", body: "Hi there", onTap: {})
    } changes: {
      $0 = UpsideDownNotificationBannerModel.Banner(
        id: UUID(0), title: "New message", body: "Hi there")
    }
    expectNoDifference(model.visibleBanners.map(\.title), ["New message"])
    expectNoDifference(model.banner?.accessibilityAnnouncement, "New message. Hi there")
  }

  @Test
  func testBannerTappedHidesBannerThenRunsTapAction() {
    let model = makeModel()
    let bannersWhenTapRan = LockIsolated<[UpsideDownNotificationBannerModel.Banner?]>([])
    model.show(title: "New message", body: "Hi there") {
      let banner = model.banner
      bannersWhenTapRan.withValue { $0.append(banner) }
    }

    model.bannerTapped()

    #expect(model.banner == nil)
    expectNoDifference(bannersWhenTapRan.value, [nil])
  }

  @Test
  func testBannerTappedAfterHideAllDoesNotRunStaleTapAction() {
    let model = makeModel()
    let tapCount = LockIsolated(0)
    model.show(title: "First", body: "") { tapCount.withValue { $0 += 1 } }
    model.show(title: "Second", body: "") { tapCount.withValue { $0 += 1 } }
    model.hideAll()

    model.bannerTapped()

    #expect(model.banner == nil)
    #expect(tapCount.value == 0)
  }

  @Test
  func testBurstOfNotificationsShowsEachInTurn() {
    let model = makeModel()
    let tappedTitles = LockIsolated<[String]>([])
    model.show(title: "First", body: "") { tappedTitles.withValue { $0.append("First") } }
    model.show(title: "Second", body: "") { tappedTitles.withValue { $0.append("Second") } }
    expectNoDifference(model.banner?.title, "First")

    model.bannerDragEnded(verticalTranslation: -40)
    expectNoDifference(model.banner?.title, "Second")

    model.bannerTapped()
    #expect(model.banner == nil)
    expectNoDifference(tappedTitles.value, ["Second"])
  }

  @Test
  func testDraggingBannerUpDismissesIt() {
    let model = makeModel()
    model.show(title: "New message", body: "Hi there", onTap: {})

    model.bannerDragEnded(verticalTranslation: -40)

    #expect(model.banner == nil)
  }

  @Test
  func testSmallOrDownwardDragKeepsBanner() {
    let model = makeModel()
    model.show(title: "New message", body: "Hi there", onTap: {})

    model.bannerDragEnded(verticalTranslation: -10)
    model.bannerDragEnded(verticalTranslation: 40)

    #expect(model.banner != nil)
  }

  @Test
  func testBannerHidesAfterDisplayDuration() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      let model = makeModel(clock: clock)
      model.show(title: "New message", body: "Hi there", onTap: {})

      let appeared = Task { await model.bannerAppeared() }
      await clock.advance(by: model.displayDuration - .milliseconds(1))
      #expect(model.banner != nil)
      await clock.advance(by: .milliseconds(1))
      await appeared.value

      #expect(model.banner == nil)
    }
  }

  @Test
  func testOlderBannerTimerDoesNotHideNextQueuedBanner() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      let model = makeModel(clock: clock)
      model.show(title: "First", body: "", onTap: {})
      model.show(title: "Second", body: "", onTap: {})
      let firstAppeared = Task { await model.bannerAppeared() }
      await Task.megaYield()
      model.bannerDragEnded(verticalTranslation: -40)

      await clock.advance(by: model.displayDuration)
      await firstAppeared.value

      expectNoDifference(model.banner?.title, "Second")
    }
  }

  private func makeModel(
    clock: TestClock<Duration> = TestClock()
  ) -> UpsideDownNotificationBannerModel {
    withDependencies {
      $0.continuousClock = clock
      $0.uuid = .incrementing
    } operation: {
      UpsideDownNotificationBannerModel()
    }
  }
}
