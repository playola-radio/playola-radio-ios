//
//  API.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation

struct API {
  static let stationsURL = URL(string: "https://playola-static.s3.amazonaws.com/station_lists.json")!
  
  // Helper struct to get either local or remote JSON
  static func getStations(completion: @escaping ((Result<[StationList], Error>) -> Void)) {
    DispatchQueue.global(qos: .userInitiated).async {
      loadHttp { remoteResult in
        if case.success = remoteResult {
          print("Remote StationLists Loaded")
          DispatchQueue.main.async {
            completion(remoteResult)
          }
        } else {
          loadLocal { stationListResult in
            print("Error loading remote StationLists. Falling back to local version.")
            DispatchQueue.main.async {
              completion(stationListResult)
            }
          }
        }
      }
    }
  }
  
  static func getStations() async throws -> [StationList] {
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
  
  private static func handle(_ dataResult: Result<Data?, Error>, _ completion: @escaping ((Result<[StationList], Error>) -> Void)) {
    DispatchQueue.main.async {
      switch dataResult {
      case .success(let data):
        let result = decode(data)
        completion(result)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
  
  private static func decode(_ data: Data?) -> Result<[StationList], Error> {
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
  
  static func loadLocal(_ completion: (Result<[StationList], Error>) -> Void) {
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
  private static func loadHttp(_ completion: @escaping (Result<[StationList], Error>) -> Void) {
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
      
      completion(decode(data))
    }
    loadDataTask.resume()
  }
}
