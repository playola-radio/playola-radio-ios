//
//  LoggedInUser.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//
import Foundation

struct Auth: Codable {
  let currentUser: LoggedInUser?
  let jwt: String?

  var isLoggedIn: Bool {
    return self.jwt != nil
  }

  init(currentUser: LoggedInUser? = nil, jwt: String? = nil) {
    self.currentUser = currentUser
    self.jwt = jwt
  }

  init(jwtToken: String) {
    self.currentUser = LoggedInUser(jwtToken: jwtToken)
    self.jwt = jwtToken
  }
}

struct LoggedInUser: Codable {
  let id: String
  let displayName: String
  let email: String
  let profileImageUrl: String?
  let role: String
  let jwt: String

  init(jwtToken jwt: String) {
    let userDict = LoggedInUser.decode(jwtToken: jwt)
    self.id = userDict["id"] as! String
    self.displayName = userDict["displayName"] as! String
    self.email = userDict["email"] as! String
    self.profileImageUrl = userDict["profileImageUrl"] as? String
    self.role = userDict["role"] as! String
    self.jwt = jwt
  }

  static func decode(jwtToken jwt: String) -> [String: Any] {
    let segments = jwt.components(separatedBy: ".")
    return LoggedInUser.decodeJWTPart(segments[1]) ?? [:]
  }

  static func base64UrlDecode(_ value: String) -> Data? {
    var base64 = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
    let requiredLength = 4 * ceil(length / 4.0)
    let paddingLength = requiredLength - length
    if paddingLength > 0 {
      let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
      base64 = base64 + padding
    }
    return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
  }

  static func decodeJWTPart(_ value: String) -> [String: Any]? {
    guard let bodyData = LoggedInUser.base64UrlDecode(value),
      let json = try? JSONSerialization.jsonObject(with: bodyData, options: []), let payload = json as? [String: Any] else {
        return nil
    }

    return payload
  }
}
