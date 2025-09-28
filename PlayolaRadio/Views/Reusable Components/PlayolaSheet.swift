//
//  PlayolaSheet.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

enum PlayolaSheet: Hashable, Identifiable, Equatable {
    var id: Self {
        self
    }

    case player(PlayerPageModel)
    case invitationCode(InvitationCodePageModel)
}
