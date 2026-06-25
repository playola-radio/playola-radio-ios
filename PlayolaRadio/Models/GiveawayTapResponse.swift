import Foundation

struct GiveawayTapResponse: Decodable, Sendable, Equatable {
  let tapNumber: Int
  let isWinner: Bool
  let status: GiveawayStatus

  static var mock: GiveawayTapResponse {
    GiveawayTapResponse(tapNumber: 5, isWinner: false, status: .open)
  }
}

/// Domain errors for a tap, translated from the transport layer inside `APIClient` so callers never
/// touch HTTP/Alamofire details. `.notOpenYet` is the expected 400 race at the open moment (callers
/// stay silent); any other failure propagates as-is for the caller to surface.
enum GiveawayTapError: Error, Equatable {
  case notOpenYet
}

/// Domain errors for submitting an artist congrats, translated from the transport layer inside
/// `APIClient`. `.windowClosed` is the server signaling the congrats window has already closed
/// (HTTP 409); the caller maps it to a terminal `.alreadyClosed` action instead of looping on a
/// pointless retry. Any other failure propagates as-is (genuinely retryable).
enum GiveawayCongratsError: Error, Equatable {
  case windowClosed
}
