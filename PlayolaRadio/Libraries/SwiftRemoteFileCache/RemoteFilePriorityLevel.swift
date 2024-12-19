//
//  RemoteFilePriorityLevel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/19/24.
//

import Foundation

public enum RemoteFilePriorityLevel:Int
{
    case doNotDelete = 10
    case high = 8
    case medium = 5
    case low = 1
    case unspecified = 0
}
