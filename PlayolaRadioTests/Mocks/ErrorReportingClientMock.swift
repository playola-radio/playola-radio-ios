//
//  ErrorReportingClientMock.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 4/23/26.
//

import Dependencies
import Foundation

@testable import PlayolaRadio

extension ErrorReportingClient {
  /// Test mock that forwards reported errors/messages to caller-supplied handlers.
  static func mock(
    errorHandler: @escaping @Sendable (Error, [String: String]) -> Void = { _, _ in },
    errorWithContextHandler:
      @escaping @Sendable (
        Error, [String: String], [String: String]
      ) -> Void = { _, _, _ in },
    messageHandler: @escaping @Sendable (String, [String: String]) -> Void = { _, _ in }
  ) -> Self {
    Self(
      reportError: { error, tags in
        errorHandler(error, tags)
      },
      reportErrorWithContext: { error, tags, context in
        errorWithContextHandler(error, tags, context)
      },
      reportMessage: { message, tags in
        messageHandler(message, tags)
      }
    )
  }
}
