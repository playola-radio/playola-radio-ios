/// The server's error body carries only a message, so the claim calls branch on HTTP status alone.
enum ClaimAPIError: Error, Equatable {
  case invalidAnswers
  case notOpen
  case conflict
  case failed

  init(status: Int?) {
    switch status {
    case 400: self = .invalidAnswers
    case 403, 404: self = .notOpen
    case 409: self = .conflict
    default: self = .failed
    }
  }
}
