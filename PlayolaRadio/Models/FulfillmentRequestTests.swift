import CustomDump
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct FulfillmentRequestTests {
  private func decode(_ json: String) throws -> FulfillmentRequest {
    try JSONDecoderWithIsoFull().decode(FulfillmentRequest.self, from: Data(json.utf8))
  }

  @Test func testDecodesServerSummary() throws {
    let request = try decode(
      """
      {"id":"r1","status":"awaiting_info","source":"giveaway","giveawayEventId":"e1",
       "userPrizeId":null,"prize":{"title":"Tour Poster","number":12,"imageUrl":null},
       "infoFields":[
         {"key":"shirtSize","label":"Shirt size","type":"SINGLE_CHOICE","options":["S","M"],"required":true},
         {"key":"shippingAddress","label":"Shipping address","type":"ADDRESS","required":true}],
       "infoAnswers":{"shirtSize":"M","shippingAddress":{"fullName":"Jane","addressLine1":"1 Main",
         "addressLine2":null,"city":"Austin","state":"TX","postalCode":"78701","country":"US"}}}
      """)
    expectNoDifference(
      request,
      FulfillmentRequest(
        id: "r1", status: .awaitingInfo, source: .giveaway, giveawayEventId: "e1",
        prizeTitle: "Tour Poster", prizeImageUrl: nil,
        infoFields: [
          InfoField(
            key: "shirtSize", label: "Shirt size", type: .singleChoice, options: ["S", "M"],
            required: true),
          InfoField(
            key: "shippingAddress", label: "Shipping address", type: .address, options: [],
            required: true),
        ],
        infoAnswers: [
          "shirtSize": .text("M"),
          "shippingAddress": .address(
            ShippingAddress(
              fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin",
              state: "TX", postalCode: "78701")),
        ]))
  }

  @Test func testUnknownEnumsFallBack() throws {
    let request = try decode(
      """
      {"id":"r1","status":"on_hold","source":"raffle","giveawayEventId":null,"prize":{},
       "infoFields":[{"key":"dob","label":"Birthday","type":"DATE","required":false}],"infoAnswers":{}}
      """)
    #expect(request.status == .unknown)
    #expect(request.source == .unknown)
    #expect(request.infoFields.first?.type == .unknown)
  }

  @Test func testUndecodableAnswerIsDropped() throws {
    let request = try decode(
      """
      {"id":"r1","status":"awaiting_info","source":"reward","giveawayEventId":null,"prize":{},
       "infoFields":[],"infoAnswers":{"a":"ok","b":42,"c":{"weird":true}}}
      """)
    expectNoDifference(request.infoAnswers, ["a": .text("ok")])
  }

  @Test func testAnswersRequestEncodesTextAndAddressWithoutCountry() throws {
    let body = SubmitFulfillmentAnswersRequest(infoAnswers: [
      "size": .text("M"),
      "addr": .address(
        ShippingAddress(
          fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
          postalCode: "78701")),
    ])
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any]
    let answers = json?["infoAnswers"] as? [String: Any]
    #expect(answers?["size"] as? String == "M")
    let addr = answers?["addr"] as? [String: Any]
    #expect(addr?["postalCode"] as? String == "78701")
    #expect(addr?["country"] == nil)
  }
}
