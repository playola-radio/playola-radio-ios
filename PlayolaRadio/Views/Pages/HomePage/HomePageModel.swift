//
//  HomePageViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import Sharing
import SwiftUI

@MainActor
@Observable
class HomePageModel: ViewModel {
  // MARK: State
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  
  var isLoadingStationLists: Bool = false
  
  
  //  init(canSendEmail: Bool = false,
  //       isShowingMailComposer: Bool = false,
  //       mailURL: URL? = nil,
  //       isShowingCannotOpenMailAlert: Bool = false,
  //       presentedAlert: PlayolaAlert? = nil,
  //       mailService: MailService = MailService(),
  //       navigationCoordinator: NavigationCoordinator = .shared)
  //  {
  //    self.canSendEmail = canSendEmail
  //    self.isShowingMailComposer = isShowingMailComposer
  //    self.mailURL = mailURL
  //    self.isShowingCannotOpenMailAlert = isShowingCannotOpenMailAlert
  //    self.presentedAlert = presentedAlert
  //    self.mailService = mailService
  //    self.navigationCoordinator = navigationCoordinator
  //  }
  
  // MARK: Actions
  
  func viewAppeared() async {}
}
