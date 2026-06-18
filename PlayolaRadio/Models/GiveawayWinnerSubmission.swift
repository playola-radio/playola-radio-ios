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

struct GiveawayWinnerSubmission: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let giveawayId: String
  let userId: String
  let fullName: String
  let addressLine1: String
  let addressLine2: String?
  let city: String
  let state: String?
  let postalCode: String
  let country: String
  let comment: String?
  let willingToRecord: Bool
  let fulfillmentStatus: FulfillmentStatus
  let submittedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, giveawayId, userId, fullName, addressLine1, addressLine2, city, state
    case postalCode, country, comment, willingToRecord, fulfillmentStatus, submittedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    giveawayId = try container.decode(String.self, forKey: .giveawayId)
    userId = try container.decode(String.self, forKey: .userId)
    fullName = try container.decode(String.self, forKey: .fullName)
    addressLine1 = try container.decode(String.self, forKey: .addressLine1)
    addressLine2 = try container.decodeIfPresent(String.self, forKey: .addressLine2)
    city = try container.decode(String.self, forKey: .city)
    state = try container.decodeIfPresent(String.self, forKey: .state)
    postalCode = try container.decode(String.self, forKey: .postalCode)
    country = try container.decode(String.self, forKey: .country)
    comment = try container.decodeIfPresent(String.self, forKey: .comment)
    willingToRecord = try container.decodeIfPresent(Bool.self, forKey: .willingToRecord) ?? false
    fulfillmentStatus = try container.decode(FulfillmentStatus.self, forKey: .fulfillmentStatus)
    submittedAt = try container.decode(Date.self, forKey: .submittedAt)
  }

  init(
    id: String,
    giveawayId: String,
    userId: String,
    fullName: String,
    addressLine1: String,
    addressLine2: String? = nil,
    city: String,
    state: String? = nil,
    postalCode: String,
    country: String,
    comment: String? = nil,
    willingToRecord: Bool,
    fulfillmentStatus: FulfillmentStatus,
    submittedAt: Date
  ) {
    self.id = id
    self.giveawayId = giveawayId
    self.userId = userId
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
      giveawayId: "giveaway-1",
      userId: "user-1",
      fullName: "Brian Keane",
      addressLine1: "123 Main St",
      city: "Austin",
      postalCode: "78701",
      country: "US",
      willingToRecord: false,
      fulfillmentStatus: .pending,
      submittedAt: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
