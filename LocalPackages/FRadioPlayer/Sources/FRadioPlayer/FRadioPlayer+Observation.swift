//
//  FRadioPlayer+Observation.swift
//  FRadioPlayer
//
//  Created by Fethi El Hassasna on 2021-10-16.
//

import Foundation

extension FRadioPlayer {
  struct Observation {
    weak var observer: FRadioPlayerObserver?
  }
}

extension FRadioPlayer {
  public func addObserver(_ observer: FRadioPlayerObserver) {
    let id = ObjectIdentifier(observer)
    observations[id] = Observation(observer: observer)
  }

  public func removeObserver(_ observer: FRadioPlayerObserver) {
    let id = ObjectIdentifier(observer)
    observations.removeValue(forKey: id)
  }
}
