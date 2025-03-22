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


extension User {
  public static var mockWithStation: User {
    return User(id: "12345", displayName: "Bob", email: "bob@bob.com", profileImageUrl: nil, role: "admin", stations: [
      .mock
    ])
  }

  public static var mockWithoutStation: User {
    return User(id: "12345", displayName: "Sue", email: "sue@sue.com", profileImageUrl: nil, role: "admin", stations: [])
  }
}
