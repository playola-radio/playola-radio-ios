//
//  YourLibraryPageTests.swift
//  PlayolaRadio
//

import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct YourLibraryPageTests {
  @Test
  func testNavigationTitleIsYourLibrary() {
    let model = YourLibraryPageModel()
    #expect(model.navigationTitle == "Your Library")
  }
}
