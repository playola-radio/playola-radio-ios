//
//  NavigationCoordinatorMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
@testable import PlayolaRadio

class NavigationCoordinatorMock: NavigationCoordinator {
  var changesToPathCount = 0
    
    override var path: [NavigationCoordinator.Path] {
      set {
        changesToPathCount += 1
        _path = newValue
      }
      get {
        return _path
      }
    }
  var _path: [NavigationCoordinator.Path] = []
}
