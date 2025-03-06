//
//  User.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/5/25.
//

struct User: Codable {
    let id: String
    let displayName: String
    let email: String
    let profileImageUrl: String?
    let role: String
    let stations: [Station]?
}
