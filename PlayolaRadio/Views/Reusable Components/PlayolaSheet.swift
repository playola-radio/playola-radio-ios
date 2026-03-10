//
//  PlayolaSheet.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

struct ShareSheetModel: Hashable, Equatable {
  let items: [String]

  static func == (lhs: ShareSheetModel, rhs: ShareSheetModel) -> Bool {
    lhs.items == rhs.items
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(items)
  }
}

enum PlayolaSheet: Hashable, Identifiable, Equatable {
  var id: Self {
    self
  }

  case player(PlayerPageModel)
  case invitationCode(InvitationCodePageModel)
  case recordPage(RecordPageModel)
  case recordIntroPage(RecordIntroPageModel)
  case songSearchPage(SongSearchPageModel)
  case feedbackSheet(FeedbackSheetModel)
  case share(ShareSheetModel)
  case redeemPrize(RedeemPrizeSheetModel)
  case artistSuggestion(StationSuggestionPageModel)
}
