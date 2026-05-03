//
//  EpisodeRowTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@MainActor
struct EpisodeRowModelTests {

  // MARK: - Tune In Text Tests (This Week)

  @Test
  func testTuneInTextThisWeekShowsDayOnly() {
    let friday = createDate(year: 2026, month: 1, day: 16, hour: 14, minute: 20)
    let saturday = createDate(year: 2026, month: 1, day: 17, hour: 14, minute: 20)

    let model = withDependencies {
      $0.date.now = friday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: saturday))
    }

    #expect(model.tuneInText == "Tune in Saturday at 2:20pm")
  }

  @Test
  func testTuneInTextThisWeekDifferentTime() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let wednesday = createDate(year: 2026, month: 1, day: 14, hour: 16, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: wednesday))
    }

    #expect(model.tuneInText == "Tune in Wednesday at 4:00pm")
  }

  // MARK: - Tune In Text Tests (Next Week)

  @Test
  func testTuneInTextNextWeekShowsNextPrefix() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let nextFriday = createDate(year: 2026, month: 1, day: 23, hour: 14, minute: 20)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: nextFriday))
    }

    #expect(model.tuneInText == "Tune in next Friday at 2:20pm")
  }

  @Test
  func testTuneInTextNextWeekDifferentDay() {
    let friday = createDate(year: 2026, month: 1, day: 16, hour: 9, minute: 0)
    let nextTuesday = createDate(year: 2026, month: 1, day: 20, hour: 19, minute: 30)

    let model = withDependencies {
      $0.date.now = friday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: nextTuesday))
    }

    #expect(model.tuneInText == "Tune in next Tuesday at 7:30pm")
  }

  // MARK: - Tune In Text Tests (Beyond Next Week)

  @Test
  func testTuneInTextBeyondNextWeekShowsDayAndDate() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 3, hour: 14, minute: 20)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Tuesday the 3rd at 2:20pm")
  }

  @Test
  func testTuneInTextBeyondNextWeekWithOrdinalSt() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 1, hour: 10, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Sunday the 1st at 10:00am")
  }

  @Test
  func testTuneInTextBeyondNextWeekWithOrdinalNd() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 2, hour: 15, minute: 45)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Monday the 2nd at 3:45pm")
  }

  @Test
  func testTuneInTextBeyondNextWeekWithOrdinalTh() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 11, hour: 20, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Wednesday the 11th at 8:00pm")
  }

  @Test
  func testTuneInTextBeyondNextWeekWithOrdinal12th() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 12, hour: 12, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Thursday the 12th at 12:00pm")
  }

  @Test
  func testTuneInTextBeyondNextWeekWithOrdinal13th() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 13, hour: 9, minute: 30)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Friday the 13th at 9:30am")
  }

  @Test
  func testTuneInTextBeyondNextWeekWithOrdinal21st() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 21, hour: 18, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    #expect(model.tuneInText == "Tune in Saturday the 21st at 6:00pm")
  }

  // MARK: - Helper

  private func createDate(
    year: Int, month: Int, day: Int, hour: Int, minute: Int
  ) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.timeZone = TimeZone.current
    return Calendar.current.date(from: components)!
  }
}
