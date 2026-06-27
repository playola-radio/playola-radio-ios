import Foundation

enum FulfillmentStatus: String, Codable, Sendable, Equatable {
  case pending
  case fulfilled
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = FulfillmentStatus(rawValue: raw) ?? .unknown
  }
}

/// A winner's submission for a per-airing giveaway event. The server keys it by `eventId` (NOT
/// `giveawayId`). Mailing-address fields are optional: the iOS app now collects only a confirmed
/// `preferredEmail` and arranges delivery over email, so a fresh submission carries no address.
struct GiveawayWinnerSubmission: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let eventId: String
  let userId: String
  let preferredEmail: String?
  let fullName: String?
  let addressLine1: String?
  let addressLine2: String?
  let city: String?
  let state: String?
  let postalCode: String?
  let country: String?
  let comment: String?
  let willingToRecord: Bool
  let fulfillmentStatus: FulfillmentStatus
  let submittedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, eventId, userId, preferredEmail, fullName, addressLine1, addressLine2, city, state
    case postalCode, country, comment, willingToRecord, fulfillmentStatus, submittedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    eventId = try container.decode(String.self, forKey: .eventId)
    userId = try container.decode(String.self, forKey: .userId)
    preferredEmail = try container.decodeIfPresent(String.self, forKey: .preferredEmail)
    fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
    addressLine1 = try container.decodeIfPresent(String.self, forKey: .addressLine1)
    addressLine2 = try container.decodeIfPresent(String.self, forKey: .addressLine2)
    city = try container.decodeIfPresent(String.self, forKey: .city)
    state = try container.decodeIfPresent(String.self, forKey: .state)
    postalCode = try container.decodeIfPresent(String.self, forKey: .postalCode)
    country = try container.decodeIfPresent(String.self, forKey: .country)
    comment = try container.decodeIfPresent(String.self, forKey: .comment)
    willingToRecord = try container.decodeIfPresent(Bool.self, forKey: .willingToRecord) ?? false
    fulfillmentStatus = try container.decode(FulfillmentStatus.self, forKey: .fulfillmentStatus)
    submittedAt = try container.decode(Date.self, forKey: .submittedAt)
  }

  init(
    id: String,
    eventId: String,
    userId: String,
    preferredEmail: String? = nil,
    fullName: String? = nil,
    addressLine1: String? = nil,
    addressLine2: String? = nil,
    city: String? = nil,
    state: String? = nil,
    postalCode: String? = nil,
    country: String? = nil,
    comment: String? = nil,
    willingToRecord: Bool,
    fulfillmentStatus: FulfillmentStatus,
    submittedAt: Date
  ) {
    self.id = id
    self.eventId = eventId
    self.userId = userId
    self.preferredEmail = preferredEmail
    self.fullName = fullName
    self.addressLine1 = addressLine1
    self.addressLine2 = addressLine2
    self.city = city
    self.state = state
    self.postalCode = postalCode
    self.country = country
    self.comment = comment
    self.willingToRecord = willingToRecord
    self.fulfillmentStatus = fulfillmentStatus
    self.submittedAt = submittedAt
  }

  static var mock: GiveawayWinnerSubmission {
    GiveawayWinnerSubmission(
      id: "sub-1",
      eventId: "event-1",
      userId: "user-1",
      preferredEmail: "winner@example.com",
      willingToRecord: false,
      fulfillmentStatus: .pending,
      submittedAt: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
