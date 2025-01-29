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
        didSet {
            changesToPathCount += 1
        }
    }
}
