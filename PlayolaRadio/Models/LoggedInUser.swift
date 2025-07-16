//
//  LoggedInUser.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//
import AuthenticationServices
import Foundation
import Sharing

struct Auth: Codable {
  let currentUser: LoggedInUser?
  let jwt: String?

  var isLoggedIn: Bool {
    jwt != nil
  }

  init(currentUser: LoggedInUser? = nil, jwt: String? = nil) {
    self.currentUser = currentUser
    self.jwt = jwt
  }

  init(jwtToken: String) {
    currentUser = LoggedInUser(jwtToken: jwtToken)
    jwt = jwtToken
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

    guard let id = userDict["id"] as? String,
      let displayName = userDict["displayName"] as? String,
      let email = userDict["email"] as? String,
      let role = userDict["role"] as? String
    else {
      self.id = ""
      self.displayName = "Unknown User"
      self.email = ""
      self.profileImageUrl = nil
      self.role = "user"
      self.jwt = jwt
      return
    }

    self.id = id
    self.displayName = displayName
    self.email = email
    self.profileImageUrl = userDict["profileImageUrl"] as? String
    self.role = role
    self.jwt = jwt
  }

  static func decode(jwtToken jwt: String) -> [String: Any] {
    let segments = jwt.components(separatedBy: ".")
    return LoggedInUser.decodeJWTPart(segments[1]) ?? [:]
  }

  static func base64UrlDecode(_ value: String) -> Data? {
    var base64 =
      value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
    let requiredLength = 4 * ceil(length / 4.0)
    let paddingLength = requiredLength - length
    if paddingLength > 0 {
      let padding = "".padding(
        toLength: Int(paddingLength),
        withPad: "=",
        startingAt: 0)
      base64 += padding
    }
    return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
  }

  static func decodeJWTPart(_ value: String) -> [String: Any]? {
    guard let bodyData = LoggedInUser.base64UrlDecode(value),
      let json = try? JSONSerialization.jsonObject(with: bodyData, options: []),
      let payload = json as? [String: Any]
    else {
      return nil
    }
    return payload
  }
}

class AuthService {
  static let shared = AuthService()
  @Shared(.appleSignInInfo) var appleSignInInfo
  @Shared(.auth) var auth: Auth

  init() {
    let sessionNotificationName = ASAuthorizationAppleIDProvider.credentialRevokedNotification
    NotificationCenter.default.addObserver(
      forName: sessionNotificationName,
      object: nil,
      queue: nil
    ) { _ in
      guard let appleSignInInfo = self.appleSignInInfo else { return }
    }
  }

  func signOut() {
    $auth.withLock { $0 = Auth() }
  }

  func clearAppleUser() {
    $appleSignInInfo.withLock { $0 = nil }
  }
}
