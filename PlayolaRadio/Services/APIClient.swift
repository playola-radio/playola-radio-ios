//
//  APIClient.swift
//  PlayolaPlayer
//
//  Created by Brian D Keane on 3/26/25.
//

import Foundation
import Alamofire
import PlayolaPlayer
import Sharing
import Dependencies

public enum APIError: Error {
  case networkError(Error)
  case decodingError(Error)
  case unauthorized
  case invalidResponse
  case serverError(Int)
  case other(Error)

  public var localizedDescription: String {
    switch self {
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    case .decodingError(let error):
      return "Failed to decode data: \(error.localizedDescription)"
    case .invalidResponse:
      return "Invalid server response"
    case .serverError(let code):
      return "Server error with code: \(code)"
    case .unauthorized:
      return "You must be signed in for this request."
    case .other(let error):
      return "Error: \(error.localizedDescription)"
    }
  }
}

public actor APIClient {
  private let baseURL = "https://admin-api.playola.fm/v1"
  private let defaultHeaders: HTTPHeaders = [
    "Content-Type": "application/json",
    "Accept": "application/json"
  ]

  @Shared(.auth) var auth
  private var authToken: String? {
    return auth.jwt
  }
  
  // Get headers including authentication token if available
  private var headers: HTTPHeaders {
    var headers = defaultHeaders
    if let authToken = authToken {
      headers.add(name: "Authorization", value: "Bearer \(authToken)")
    }
    return headers
  }

  // MARK: - Public API Methods

  /// Fetch a station's schedule
  /// - Parameters:
  ///   - stationId: The ID of the station
  ///   - extended: Whether to include extended information
  /// - Returns: A Schedule object containing the fetched spins
  public func fetchSchedule(stationId: String, extended: Bool = false) async throws -> Schedule {
    let urlString = "\(baseURL)/stations/\(stationId)/schedule"
    let parameters: [String: Bool] = ["extended": extended]

    do {
      // Make the network request
      let spins: [Spin] = try await performRequest(
        urlString: urlString,
        method: .get,
        parameters: parameters
      )

      // Create and return the schedule
      return Schedule(stationId: stationId, spins: spins)
    } catch {
      throw mapToAPIError(error)
    }
  }

  /// Fetch stations for a user
  /// - Parameter userId: The ID of the user
  /// - Returns: An array of Station objects
  public func fetchUserStations(userId: String) async throws -> [Station] {
      guard authToken != nil else {
          throw APIError.unauthorized
      }

      let urlString = "\(baseURL)/users/\(userId)/stations"

      do {
          // Make the network request
          return try await performRequest(
              urlString: urlString,
              method: .get
          )
      } catch {
          throw mapToAPIError(error)
      }
  }


  // MARK: - Private Helper Methods

  /// Perform a network request and decode the response using Alamofire's native async/await support
  /// - Parameters:
  ///   - urlString: The URL string for the API endpoint
  ///   - method: The HTTP method to use
  ///   - parameters: Optional query parameters
  ///   - encoding: Parameter encoding (defaults to URLEncoding.default)
  /// - Returns: Decoded object of specified type
  private func performRequest<T: Decodable & Sendable>(
    urlString: String,
    method: HTTPMethod,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.default
  ) async throws -> T {
    // Use Alamofire's native async API
    let decoder = JSONDecoderWithIsoFull()

    let response = try await AF.request(
      urlString,
      method: method,
      parameters: parameters,
      encoding: encoding,
      headers: headers
    )
      .validate(statusCode: 200..<300)
      .serializingDecodable(T.self, decoder: decoder)
      .value

    return response
  }

  /// Map Alamofire errors to APIError types
  private func mapToAPIError(_ error: Error) -> APIError {
    if let afError = error as? AFError {
      switch afError {
      case .sessionTaskFailed(let error):
        return .networkError(error)
      case .responseSerializationFailed(let reason):
        if case .decodingFailed(let error) = reason {
          return .decodingError(error)
        }
        return .decodingError(afError)
      case .responseValidationFailed(let reason):
        if case .unacceptableStatusCode(let code) = reason, code >= 400 {
          return .serverError(code)
        }
        return .invalidResponse
      default:
        return .other(afError)
      }
    }
    return .other(error)
  }
}

extension APIClient: DependencyKey {
  public static let liveValue = APIClient()
}
