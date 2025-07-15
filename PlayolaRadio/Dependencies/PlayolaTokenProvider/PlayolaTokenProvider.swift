//
//  PlayolaTokenProvider.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 2/13/25.
//

import Foundation
import PlayolaPlayer
import Sharing

/// Provides JWT tokens from the app's AuthService to PlayolaPlayer
class PlayolaTokenProvider: PlayolaAuthenticationProvider {
  @Shared(.auth) private var auth: Auth

  func getCurrentToken() async -> String? {
    return auth.jwt
  }

  func refreshToken() async -> String? {
    return auth.jwt
  }
}
