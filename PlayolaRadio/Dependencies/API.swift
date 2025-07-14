//
//  API.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Alamofire
import Foundation
import IdentifiedCollections
import Sharing

class API {
  static let stationsURL = URL(
    string: "\(Config.shared.baseUrl.absoluteString)/v1/developer/stationLists")!

  @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList>
  @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @Shared(.auth) var auth: Auth

  // Helper struct to get either local or remote JSON
  func getStations(
    completion: @escaping (
      (Result<IdentifiedArrayOf<StationList>, Error>) -> Void
    )
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      self.loadHttp { remoteResult in
        switch remoteResult {
        case let .success(stationLists):
          print("Remote StationLists Loaded")
          self.$stationLists.withLock {
            $0 = IdentifiedArrayOf(uniqueElements: stationLists)
          }
          self.$stationListsLoaded.withLock { $0 = true }
          DispatchQueue.main.async {
            completion(.success(self.stationLists))
          }
        default:
          self.loadLocal { _ in
            print(
              "Error loading remote StationLists. Falling back to local version."
            )
            DispatchQueue.main.async {
              completion(.success(self.stationLists))
            }
          }
        }
      }
    }
  }

  func signInViaApple(
    identityToken: String,
    email: String,
    authCode: String,
    displayName: String?
  ) async {
    var parameters: [String: Any] = [
      "identityToken": identityToken,
      "authCode": authCode,
      "email": email,
    ]
    if let displayName {
      parameters["displayName"] = displayName
    }
    AF.request(
      "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/mobile/signup",
      method: .post,
      parameters: parameters,
      encoding: JSONEncoding.default
    ).responseDecodable(of: LoginResponse.self) { response in
      switch response.result {
      case let .success(loginResponse):
        self.$auth.withLock { $0 = Auth(jwtToken: loginResponse.playolaToken) }
      case let .failure(error):
        print("Failure to log in: \(error)")
      }
    }
  }

  func revokeAppleCredentials(appleUserId: String) async {
    let parameters: [String: Any] = ["appleUserId": appleUserId]
    AF.request(
      "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/revoke",
      method: .put,
      parameters: parameters,
      encoding: JSONEncoding.default
    )
    .validate(statusCode: 200..<300)
    .response { _ in
      AuthService.shared.signOut()
      AuthService.shared.clearAppleUser()
    }
  }

  func signInViaGoogle(code: String) async {
    let parameters: [String: Any] = [
      "code": code,
      "originatesFromIOS": true,
    ]

    AF.request(
      "\(Config.shared.baseUrl.absoluteString)/v1/auth/google/signin",
      method: .post,
      parameters: parameters,
      encoding: JSONEncoding.default
    )
    .validate(statusCode: 200..<300)
    .responseDecodable(of: LoginResponse.self) { response in
      switch response.result {
      case let .success(loginResponse):
        self.$auth.withLock { $0 = Auth(jwtToken: loginResponse.playolaToken) }
      case let .failure(error):
        print("Failure to log in: \(error)")
      }
    }
  }

  @discardableResult
  func getStations() async throws -> IdentifiedArrayOf<StationList> {
    try await withCheckedThrowingContinuation { continuation in
      getStations { stationListResult in
        switch stationListResult {
        case let .success(stationLists):
          continuation.resume(returning: stationLists)
        case let .failure(error):
          continuation.resume(throwing: error)
        }
      }
    }
  }

  enum DataError: Error {
    case urlNotValid, dataNotValid, dataNotFound, fileNotFound,
      httpResponseNotValid
  }

  private func handle(
    _ dataResult: Result<Data?, Error>,
    _ completion: @escaping ((Result<[StationList], Error>) -> Void)
  ) {
    DispatchQueue.main.async {
      switch dataResult {
      case let .success(data):
        let result = self.decode(data)
        completion(result)
      case let .failure(error):
        completion(.failure(error))
      }
    }
  }

  private func decode(_ data: Data?) -> Result<[StationList], Error> {
    guard let data else {
      return .failure(DataError.dataNotFound)
    }

    let jsonDictionary: [String: [StationList]]

    do {
      jsonDictionary = try JSONDecoder().decode(
        [String: [StationList]].self, from: data)
    } catch {
      return .failure(error)
    }

    guard let stationLists = jsonDictionary["stationLists"] else {
      return .failure(DataError.dataNotValid)
    }

    return .success(stationLists)
  }

  // Load local JSON Data

  func loadLocal(_ completion: (Result<[StationList], Error>) -> Void) {
    let filePathURL = Bundle.main.url(
      forResource: "station_lists", withExtension: "json")
    guard let filePathURL else {
      completion(.failure(DataError.fileNotFound))
      return
    }

    do {
      let data = try Data(contentsOf: filePathURL, options: .uncached)
      completion(decode(data))
    } catch {
      completion(.failure(error))
    }
  }

  // Load http JSON Data
  private func loadHttp(
    _ completion: @escaping (Result<[StationList], Error>) -> Void
  ) {
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData

    let session = URLSession(configuration: config)

    // Use URLSession to get data from an NSURL
    let loadDataTask = session.dataTask(with: API.stationsURL) {
      data, response, error in

      if let error {
        completion(.failure(error))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse,
        200...299 ~= httpResponse.statusCode
      else {
        completion(.failure(DataError.httpResponseNotValid))
        return
      }

      guard let data else {
        completion(.failure(DataError.dataNotFound))
        return
      }

      completion(self.decode(data))
    }
    loadDataTask.resume()
  }
}

struct LoginResponse: Decodable {
  let playolaToken: String
}
