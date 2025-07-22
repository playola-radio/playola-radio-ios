//
//  EnumTypeEquatableProtocol.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

protocol EnumTypeEquatable {
  static func ~= (lhs: Self, rhs: Self) -> Bool
  static func ~= (lhs: Self?, rhs: Self) -> Bool
  static func ~= (lhs: Self, rhs: Self?) -> Bool
}

extension EnumTypeEquatable {
  static func ~= (lhs: Self?, rhs: Self) -> Bool {
    guard let lhs else { return false }
    return lhs ~= rhs
  }

  static func ~= (lhs: Self, rhs: Self?) -> Bool {
    guard let rhs else { return false }
    return lhs ~= rhs
  }
}

extension PlayolaSheet: EnumTypeEquatable {
  static func ~= (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.player, .player): return true
    default: return false
    }
  }
}

extension StationPlayer.PlaybackStatus: EnumTypeEquatable {
  static func ~= (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.stopped, .stopped): return true
    case (.playing, .playing): return true
    case (.loading, .loading): return true
    case (.error, .error): return true
    default: return false
    }
  }
}

extension NavigationCoordinator.Path: EnumTypeEquatable {
  static func ~= (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.stationListPage, .stationListPage): return true
    case (.nowPlayingPage, .nowPlayingPage): return true
    default: return false
    }
  }
}
