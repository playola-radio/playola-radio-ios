import Foundation

struct FulfillmentRequest: Decodable, Equatable, Identifiable, Sendable {
  enum Status: String, Decodable, Sendable {
    case awaitingInfo = "awaiting_info"
    case readyToShip = "ready_to_ship"
    case unknown

    init(from decoder: Decoder) throws {
      self = Status(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
  }

  enum Source: String, Decodable, Sendable {
    case giveaway, reward, unknown

    init(from decoder: Decoder) throws {
      self = Source(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
  }

  let id: String
  let status: Status
  let source: Source
  let giveawayEventId: String?
  let prizeTitle: String?
  let prizeImageUrl: URL?
  let infoFields: [InfoField]
  let infoAnswers: [String: InfoAnswer]
}

// Decoding lives in an extension so Swift still synthesizes the memberwise init.
extension FulfillmentRequest {
  private enum CodingKeys: String, CodingKey {
    case id, status, source, giveawayEventId, prize, infoFields, infoAnswers
  }
  private enum PrizeKeys: String, CodingKey { case title, imageUrl }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    status = try container.decode(Status.self, forKey: .status)
    source = try container.decode(Source.self, forKey: .source)
    giveawayEventId = try container.decodeIfPresent(String.self, forKey: .giveawayEventId)
    let prize = try container.nestedContainer(keyedBy: PrizeKeys.self, forKey: .prize)
    prizeTitle = try prize.decodeIfPresent(String.self, forKey: .title)
    prizeImageUrl = (try? prize.decodeIfPresent(String.self, forKey: .imageUrl))
      .flatMap { $0 }
      .flatMap(URL.init(string:))
    infoFields = try container.decodeIfPresent([InfoField].self, forKey: .infoFields) ?? []
    let raw =
      try container.decodeIfPresent([String: LossyInfoAnswer].self, forKey: .infoAnswers) ?? [:]
    infoAnswers = raw.compactMapValues(\.value)
  }
}

struct InfoField: Decodable, Equatable, Sendable {
  enum FieldType: String, Decodable, Sendable {
    case shortText = "SHORT_TEXT"
    case multiLineText = "MULTI_LINE_TEXT"
    case singleChoice = "SINGLE_CHOICE"
    case address = "ADDRESS"
    case unknown

    init(from decoder: Decoder) throws {
      self = FieldType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
  }

  let key: String
  let label: String
  let type: FieldType
  let options: [String]
  let required: Bool
}

extension InfoField {
  private enum CodingKeys: String, CodingKey { case key, label, type, options, required }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    key = try container.decode(String.self, forKey: .key)
    label = try container.decode(String.self, forKey: .label)
    type = try container.decode(FieldType.self, forKey: .type)
    options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
    required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
  }
}

enum InfoAnswer: Codable, Equatable, Sendable {
  case text(String)
  case address(ShippingAddress)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let text = try? container.decode(String.self) {
      self = .text(text)
    } else {
      self = .address(try container.decode(ShippingAddress.self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .text(let text): try container.encode(text)
    case .address(let address): try container.encode(address)
    }
  }
}

/// Decodes one stored answer without failing the whole request on a value the app can't read.
private struct LossyInfoAnswer: Decodable {
  let value: InfoAnswer?

  init(from decoder: Decoder) throws { value = try? InfoAnswer(from: decoder) }
}

struct SubmitFulfillmentAnswersRequest: Encodable, Equatable, Sendable {
  let infoAnswers: [String: InfoAnswer]
}

struct CreateRewardRedemptionRequest: Encodable, Equatable, Sendable {
  let prizeId: String
}

extension FulfillmentRequest {
  static func mock(
    id: String = "request-1", status: Status = .awaitingInfo, source: Source = .giveaway,
    giveawayEventId: String? = "event-1", prizeTitle: String? = "Signed Bri Bagwell tour shirt",
    prizeImageUrl: URL? = nil,
    infoFields: [InfoField] = [
      InfoField(
        key: "shippingAddress", label: "Shipping address", type: .address, options: [],
        required: true)
    ],
    infoAnswers: [String: InfoAnswer] = [:]
  ) -> FulfillmentRequest {
    FulfillmentRequest(
      id: id, status: status, source: source, giveawayEventId: giveawayEventId,
      prizeTitle: prizeTitle, prizeImageUrl: prizeImageUrl, infoFields: infoFields,
      infoAnswers: infoAnswers)
  }
}
