//
//  RecordPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class RecordPageTests: XCTestCase {
  func testViewAppeared() async {
    let model = RecordPageModel()
    await model.viewAppeared()
    // TODO: Add assertions when functionality is implemented
  }
}
