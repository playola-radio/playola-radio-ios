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
  let jwtUser: JWTUser?
  let jwt: String?

  var isLoggedIn: Bool {
    jwt != nil
  }

  init(currentUser: JWTUser? = nil, jwt: String? = nil) {
    self.jwtUser = currentUser
    self.jwt = jwt
  }

  init(jwtToken: String) {
    jwtUser = JWTUser(jwtToken: jwtToken)
    jwt = jwtToken
  }
}

struct JWTUser: Codable {
  let id: String
  let displayName: String
  let email: String
  let profileImageUrl: String?
  let role: String
  let jwt: String

  init(jwtToken jwt: String) {
    let userDict = JWTUser.decode(jwtToken: jwt)
    id = userDict["id"] as! String
    displayName = userDict["displayName"] as! String
    email = userDict["email"] as! String
    profileImageUrl = userDict["profileImageUrl"] as? String
    role = userDict["role"] as! String
    self.jwt = jwt
  }

  static func decode(jwtToken jwt: String) -> [String: Any] {
    let segments = jwt.components(separatedBy: ".")
    return JWTUser.decodeJWTPart(segments[1]) ?? [:]
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
    guard let bodyData = JWTUser.base64UrlDecode(value),
          let json = try? JSONSerialization.jsonObject(with: bodyData, options: []), let payload = json as? [String: Any]
    else {
      return nil
    }
    return payload
  }
}

class AuthService {
  static let shared = AuthService()

  var api: API = API()
  @Shared(.appleSignInInfo) var appleSignInInfo
  @Shared(.auth) var auth: Auth
  @Shared(.currentUser) var currentUser: User?

  init() {
    let sessionNotificationName = ASAuthorizationAppleIDProvider.credentialRevokedNotification
    NotificationCenter.default.addObserver(forName: sessionNotificationName, object: nil, queue: nil) { _ in
      guard let appleSignInInfo = self.appleSignInInfo else { return }
    }

    $auth.publisher.sink { [weak self] auth in
      guard let userId = auth.jwtUser?.id else {
        self?.$currentUser.withLock { $0 = nil }
        return
      }
      Task {
        let user = try await self?.api.getUser(userId: userId)
        self?.$currentUser.withLock { $0 = user }
      }
    }
  }

  func signOut() {
    $auth.withLock { $0 = Auth() }
  }

  func clearAppleUser() {
    $appleSignInInfo.withLock { $0 = nil }
  }
}
