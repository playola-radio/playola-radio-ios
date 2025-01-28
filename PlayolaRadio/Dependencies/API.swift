//
//  API.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation
import Sharing
import IdentifiedCollections
import Alamofire

class API {
  static let stationsURL = URL(string: "\(Config.shared.baseUrl)/v1/developer/stationLists")!

  @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList>
  @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @Shared(.auth) var auth: Auth

  // Helper struct to get either local or remote JSON
  func getStations(completion: @escaping ((Result<IdentifiedArrayOf<StationList>, Error>) -> Void)) {
    DispatchQueue.global(qos: .userInitiated).async {
      self.loadHttp { remoteResult in
        switch remoteResult {
        case .success(let stationLists):
          print("Remote StationLists Loaded")
          self.$stationLists.withLock { $0 = IdentifiedArrayOf(uniqueElements: stationLists) }
          self.$stationListsLoaded.withLock { $0 = true }
          DispatchQueue.main.async {
            completion(.success(self.stationLists))
          }
        default:
          self.loadLocal { stationListResult in
            print("Error loading remote StationLists. Falling back to local version.")
            DispatchQueue.main.async {
              completion(.success(self.stationLists))
            }
          }
        }
      }
    }
  }

  func signInViaApple(identityToken: String,
                      email: String,
                      authCode: String,
                      displayName: String?) {
    var parameters: [String: Any] = [
      "identityToken": identityToken,
      "authCode": authCode,
      "email": email
    ]
    if let displayName {
      parameters["displayName"] = displayName
    }
    AF.request("\(Config.shared.baseUrl)/v1/auth/apple/mobile/signup",
               method: .post,
               parameters: parameters,
               encoding: JSONEncoding.default).responseDecodable(of: LoginResponse.self) { response in
      switch response.result {
      case .success(let loginResponse):
        self.$auth.withLock { $0 = Auth(jwtToken: loginResponse.playolaToken) }
      case .failure(let error):
        print("Failure to log in: \(error)")
      }
    }
  }

  func revokeAppleCredentials(appleUserId: String) {
    let parameters: [String: Any] = ["appleUserId": appleUserId]
    AF.request("\(Config.shared.baseUrl)/v1/auth/apple/revoke",
               method: .put,
               parameters: parameters,
               encoding: JSONEncoding.default)
    .validate(statusCode: 200..<300)
    .response { data in
      AuthService.shared.signOut()
      AuthService.shared.clearAppleUser()
    }
  }

  func signInViaGoogle(code: String) {
    let parameters: [String: Any] = [
      "code": code,
      "originatesFromIOS": true
    ]

    AF.request("\(Config.shared.baseUrl)/v1/auth/google/signin",
               method: .post,
               parameters: parameters,
               encoding: JSONEncoding.default)
      .validate(statusCode: 200..<300)
      .responseDecodable(of: LoginResponse.self)
    { response in
      switch response.result {
      case .success(let loginResponse):
        self.$auth.withLock { $0 = Auth(jwtToken: loginResponse.playolaToken) }
      case .failure(let error):
        print("Failure to log in: \(error)")
      }
    }
  }


  func getStations() async throws -> IdentifiedArrayOf<StationList> {
    try await withCheckedThrowingContinuation { continuation in
      getStations { stationListResult in
        switch stationListResult {
        case .success(let stationLists):
          continuation.resume(returning: stationLists)
        case .failure(let error):
          continuation.resume(throwing: error)
        }

      }
    }
  }


  enum DataError: Error {
    case urlNotValid, dataNotValid, dataNotFound, fileNotFound, httpResponseNotValid
  }

  private func handle(_ dataResult: Result<Data?, Error>, _ completion: @escaping ((Result<[StationList], Error>) -> Void)) {
    DispatchQueue.main.async {
      switch dataResult {
      case .success(let data):
        let result = self.decode(data)
        completion(result)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  private func decode(_ data: Data?) -> Result<[StationList], Error> {
    guard let data = data else {
      return .failure(DataError.dataNotFound)
    }

    let jsonDictionary: [String: [StationList]]

    do {
      jsonDictionary = try JSONDecoder().decode([String: [StationList]].self, from: data)
    } catch let error {
      return .failure(error)
    }

    guard let stationLists = jsonDictionary["stationLists"] else {
      return .failure(DataError.dataNotValid)
    }

    return .success(stationLists)
  }

  // Load local JSON Data

  func loadLocal(_ completion: (Result<[StationList], Error>) -> Void) {
    let filePathURL = Bundle.main.url(forResource: "station_lists", withExtension: "json")
    guard let filePathURL = filePathURL else {
      completion(.failure(DataError.fileNotFound))
      return
    }

    do {
      let data = try Data(contentsOf: filePathURL, options: .uncached)
      completion(decode(data))
    } catch let error {
      completion(.failure(error))
    }
  }

  // Load http JSON Data
  private func loadHttp(_ completion: @escaping (Result<[StationList], Error>) -> Void) {
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData

    let session = URLSession(configuration: config)

    // Use URLSession to get data from an NSURL
    let loadDataTask = session.dataTask(with: API.stationsURL) { data, response, error in

      if let error = error {
        completion(.failure(error))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
        completion(.failure(DataError.httpResponseNotValid))
        return
      }

      guard let data = data else {
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
