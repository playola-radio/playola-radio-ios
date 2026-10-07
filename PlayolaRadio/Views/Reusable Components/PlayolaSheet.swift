//
//  PlayolaSheet.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

import CasePaths

struct ShareSheetModel: Hashable, Equatable {
  let items: [String]

  static func == (lhs: ShareSheetModel, rhs: ShareSheetModel) -> Bool {
    lhs.items == rhs.items
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(items)
  }
}

@CasePathable
enum PlayolaSheet: Hashable, Identifiable, Equatable {
  var id: Self {
    self
  }

  case player(PlayerPageModel)
  case recordPage(RecordPageModel)
  case recordIntroPage(RecordIntroPageModel)
  case songSearchPage(SongSearchPageModel)
  case curatorSongPicker(CuratorSongPickerPageModel)
  case feedbackSheet(FeedbackSheetModel)
  case share(ShareSheetModel)
  case redeemPrize(RedeemPrizeSheetModel)
  case artistSuggestion(StationSuggestionPageModel)
  case welcomeMessage(WelcomeMessagePageModel)
  case giveawayCongrats(GiveawayCongratsSheetModel)
  case developerOptions(DeveloperOptionsSheetModel)
  case claim(ClaimSheetModel)
}
