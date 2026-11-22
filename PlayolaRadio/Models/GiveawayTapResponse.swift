import Foundation

struct GiveawayTapResponse: Decodable, Sendable, Equatable {
  let tapNumber: Int
  let isWinner: Bool
  let status: GiveawayStatus

  static var mock: GiveawayTapResponse {
    GiveawayTapResponse(tapNumber: 5, isWinner: false, status: .open)
  }
}

/// Domain errors for a tap. `APIClient` translates the server's 400 ("not open for taps") into
/// `.notOpenYet` so callers never touch HTTP/Alamofire details. The server sends that same 400 when
/// the contest is already due to close, so `GiveawayCoordinator` turns one received at or after the
/// event's open time into `.ended` for the listener. Any other failure propagates as-is.
enum GiveawayTapError: Error, Equatable {
  case notOpenYet
  case ended
}

/// Domain errors for submitting an artist congrats, translated from the transport layer inside
/// `APIClient`. `.windowClosed` is the server signaling the congrats window has already closed
/// (HTTP 409); the caller maps it to a terminal `.alreadyClosed` action instead of looping on a
/// pointless retry. Any other failure propagates as-is (genuinely retryable).
enum GiveawayCongratsError: Error, Equatable {
  case windowClosed
}
