import Foundation

/// The winner confirms how to reach them; the team arranges prize delivery over email. The full
/// mailing address is intentionally NOT collected in-app (too much friction at the "you won" moment).
struct GiveawayWinnerSubmissionRequest: Encodable, Equatable, Sendable {
  var preferredEmail: String

  var asParameters: [String: String] {
    ["preferredEmail": preferredEmail]
  }
}
