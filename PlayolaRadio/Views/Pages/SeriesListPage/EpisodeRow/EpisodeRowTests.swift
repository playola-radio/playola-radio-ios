//
//  EpisodeRowTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

@MainActor
final class EpisodeRowModelTests: XCTestCase {

  // MARK: - Tune In Text Tests (This Week)

  func testTuneInTextThisWeekShowsDayOnly() {
    let friday = createDate(year: 2026, month: 1, day: 16, hour: 14, minute: 20)
    let saturday = createDate(year: 2026, month: 1, day: 17, hour: 14, minute: 20)

    let model = withDependencies {
      $0.date.now = friday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: saturday))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Saturday at 2:20pm")
  }

  func testTuneInTextThisWeekDifferentTime() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let wednesday = createDate(year: 2026, month: 1, day: 14, hour: 16, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: wednesday))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Wednesday at 4:00pm")
  }

  // MARK: - Tune In Text Tests (Next Week)

  func testTuneInTextNextWeekShowsNextPrefix() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let nextFriday = createDate(year: 2026, month: 1, day: 23, hour: 14, minute: 20)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: nextFriday))
    }

    XCTAssertEqual(model.tuneInText, "Tune in next Friday at 2:20pm")
  }

  func testTuneInTextNextWeekDifferentDay() {
    let friday = createDate(year: 2026, month: 1, day: 16, hour: 9, minute: 0)
    let nextTuesday = createDate(year: 2026, month: 1, day: 20, hour: 19, minute: 30)

    let model = withDependencies {
      $0.date.now = friday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: nextTuesday))
    }

    XCTAssertEqual(model.tuneInText, "Tune in next Tuesday at 7:30pm")
  }

  // MARK: - Tune In Text Tests (Beyond Next Week)

  func testTuneInTextBeyondNextWeekShowsDayAndDate() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 3, hour: 14, minute: 20)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Tuesday the 3rd at 2:20pm")
  }

  func testTuneInTextBeyondNextWeekWithOrdinalSt() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 1, hour: 10, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Sunday the 1st at 10:00am")
  }

  func testTuneInTextBeyondNextWeekWithOrdinalNd() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 2, hour: 15, minute: 45)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Monday the 2nd at 3:45pm")
  }

  func testTuneInTextBeyondNextWeekWithOrdinalTh() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 11, hour: 20, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Wednesday the 11th at 8:00pm")
  }

  func testTuneInTextBeyondNextWeekWithOrdinal12th() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 12, hour: 12, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Thursday the 12th at 12:00pm")
  }

  func testTuneInTextBeyondNextWeekWithOrdinal13th() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 13, hour: 9, minute: 30)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Friday the 13th at 9:30am")
  }

  func testTuneInTextBeyondNextWeekWithOrdinal21st() {
    let monday = createDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
    let farFuture = createDate(year: 2026, month: 2, day: 21, hour: 18, minute: 0)

    let model = withDependencies {
      $0.date.now = monday
    } operation: {
      EpisodeRowModel(airing: .mockWith(airtime: farFuture))
    }

    XCTAssertEqual(model.tuneInText, "Tune in Saturday the 21st at 6:00pm")
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
