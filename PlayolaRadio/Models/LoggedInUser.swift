//
//  LoggedInUser.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//
import AuthenticationServices
import Foundation
import Sharing

public struct Auth: Codable {
  public let currentUser: LoggedInUser?
  public let jwt: String?

  public var isLoggedIn: Bool {
    jwt != nil
  }

  public init(currentUser: LoggedInUser? = nil, jwt: String? = nil) {
    self.currentUser = currentUser
    self.jwt = jwt
  }

  public init(jwtToken: String) {
    currentUser = LoggedInUser(jwtToken: jwtToken)
    jwt = jwtToken
  }

  public init(loggedInUser: LoggedInUser) {
    currentUser = loggedInUser
    jwt = loggedInUser.jwt
  }
}

public struct LoggedInUser: Codable {
  public let id: String
  public let firstName: String
  public let lastName: String?
  public let email: String
  public let profileImageUrl: String?
  public let role: String
  public let jwt: String

  public init(jwtToken jwt: String) {
    let userDict = LoggedInUser.decode(jwtToken: jwt)

    guard let id = userDict["id"] as? String,
      let firstName = userDict["firstName"] as? String,
      let email = userDict["email"] as? String,
      let role = userDict["role"] as? String
    else {
      self.id = ""
      self.firstName = "Unknown"
      self.lastName = "User"
      self.email = ""
      self.profileImageUrl = nil
      self.role = "user"
      self.jwt = jwt
      return
    }

    self.id = id
    self.firstName = firstName
    self.lastName = userDict["lastName"] as? String
    self.email = email
    self.profileImageUrl = userDict["profileImageUrl"] as? String
    self.role = role
    self.jwt = jwt
  }

  public init(
    id: String, firstName: String, lastName: String? = nil, email: String,
    profileImageUrl: String? = nil,
    role: String = "user"
  ) {
    self.id = id
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.profileImageUrl = profileImageUrl
    self.role = role
    self.jwt = LoggedInUser.generateJWT(
      id: id, firstName: firstName, lastName: lastName, email: email,
      profileImageUrl: profileImageUrl, role: role)
  }

  public var fullName: String {
    var constructedName = firstName
    if let lastName {
      constructedName += " \(lastName)"
    }
    return constructedName
  }

  private static func generateJWT(
    id: String, firstName: String, lastName: String? = nil, email: String, profileImageUrl: String?,
    role: String
  ) -> String {
    let header = ["alg": "HS256", "typ": "JWT"]
    var payload: [String: Any] = [
      "id": id,
      "firstName": firstName,
      "lastName": lastName ?? "",
      "email": email,
      "role": role,
    ]

    if let profileImageUrl = profileImageUrl {
      payload["profileImageUrl"] = profileImageUrl
    }

    let encodedHeader = LoggedInUser.base64URLEncode(dictionary: header)
    let encodedPayload = LoggedInUser.base64URLEncode(dictionary: payload)

    return "\(encodedHeader).\(encodedPayload).fake_signature"
  }

  private static func base64URLEncode(dictionary: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {
      return ""
    }

    return data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  public static func decode(jwtToken jwt: String) -> [String: Any] {
    let segments = jwt.components(separatedBy: ".")
    return LoggedInUser.decodeJWTPart(segments[1]) ?? [:]
  }

  public static func base64UrlDecode(_ value: String) -> Data? {
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

  public static func decodeJWTPart(_ value: String) -> [String: Any]? {
    guard let bodyData = LoggedInUser.base64UrlDecode(value),
      let json = try? JSONSerialization.jsonObject(with: bodyData, options: []),
      let payload = json as? [String: Any]
    else {
      return nil
    }
    return payload
  }
}

open class AuthService {
  public static let shared = AuthService()
  @Shared(.appleSignInInfo) var appleSignInInfo
  @Shared(.auth) var auth: Auth

  public init() {
    let sessionNotificationName = ASAuthorizationAppleIDProvider.credentialRevokedNotification
    NotificationCenter.default.addObserver(
      forName: sessionNotificationName,
      object: nil,
      queue: nil
    ) { _ in
      guard let appleSignInInfo = self.appleSignInInfo else { return }
    }
  }

  open func signOut() {
    $auth.withLock { $0 = Auth() }
  }

  public func clearAppleUser() {
    $appleSignInInfo.withLock { $0 = nil }
  }
}
