//
//  KoozieShippingAddress.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import Foundation

/// US shipping address captured when a koozie is claimed. `country` is intentionally omitted
/// from the wire body — the server defaults it to "US". `state` is sent as a 2-letter code
/// (server uppercases regardless).
struct KoozieShippingAddress: Encodable, Equatable, Sendable {
  var fullName: String
  var addressLine1: String
  var addressLine2: String?
  var city: String
  var state: String
  var postalCode: String
}

/// Redeem request body. `stationId` is omitted for the koozie.
struct RedeemKooziePrizeRequest: Encodable, Sendable {
  let shippingAddress: KoozieShippingAddress
}
