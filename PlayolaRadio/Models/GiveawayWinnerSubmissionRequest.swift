import Foundation

struct GiveawayWinnerSubmissionRequest: Encodable, Equatable, Sendable {
  var fullName: String
  var addressLine1: String
  var city: String
  var state: String
  var postalCode: String
  var addressLine2: String?
  var country: String = "US"
  var comment: String?

  var asParameters: [String: String] {
    var parameters: [String: String] = [
      "fullName": fullName,
      "addressLine1": addressLine1,
      "city": city,
      "state": state,
      "postalCode": postalCode,
      "country": country,
    ]
    if let addressLine2, !addressLine2.isEmpty { parameters["addressLine2"] = addressLine2 }
    if let comment, !comment.isEmpty { parameters["comment"] = comment }
    return parameters
  }
}
