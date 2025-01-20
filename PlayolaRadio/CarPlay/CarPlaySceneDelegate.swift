//
//  CarPlaySceneDelegate.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import CarPlay
import Combine
import Sharing
import IdentifiedCollections
import FRadioPlayer

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

  private func tabImage(_ identifier: String) -> UIImage? {
    switch identifier {
    case StationList.KnownIDs.artistList.rawValue:
      return UIImage(systemName: "music.mic.circle")
    case StationList.KnownIDs.fmStationsList.rawValue:
      return UIImage(systemName: "radio")
    default:
      return UIImage(systemName: "music.mic.circle")
    }
  }

  var disposables = Set<AnyCancellable>()

  var interfaceController: CPInterfaceController?

  @Shared(.stationLists) var stationLists
  @Shared(.showSecretStations) var showSecretStations

  var tabBarTemplate: CPTabBarTemplate?

  var observers = Set<AnyCancellable>()

  var trackingService = TrackingService.shared

  // dependency injection
  var stationPlayer: StationPlayer { return StationPlayer.shared }

  private func playStation(_ station: RadioStation?) {
    guard let station else { return }
    self.stationPlayer.play(station: station)
    showNowPlayingTemplate()
  }

  private func sectionFromStations(_ stations: [RadioStation]) -> CPListSection {
    let listItems: [CPListItem] = stations.map { station in
      let listItem = self.cPListItemFrom(station: station)
      listItem.handler = { ite, completion in
        self.playStation(station)
        completion()
      }
      return listItem
    }
    return CPListSection(items: listItems)
  }

  private func templateFromStationList(_ stationList: StationList) -> CPListTemplate {
    let section = sectionFromStations(stationList.stations)
    let template = CPListTemplate(title: stationList.title, sections: [section])
    template.tabTitle = stationList.title
    template.tabImage = tabImage(stationList.id)
    return template
  }

  func generateTemplates(_ stationLists: IdentifiedArrayOf<StationList>) -> [CPListTemplate] {
    return stationLists
      .filter{ $0.stations.count > 0 }
      .filter{ $0.id != StationList.KnownIDs.inDevelopmentList.rawValue || showSecretStations == true }
      .map{ templateFromStationList($0) }
  }

  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
    trackingService.reportEvent(.carplayInitialized)
    self.$stationLists.publisher
      .sink { stationLists in
        let newTemplates = self.generateTemplates(stationLists)
        self.tabBarTemplate?.updateTemplates(newTemplates)
      }
      .store(in: &observers)

    self.interfaceController = interfaceController
    self.interfaceController?.delegate = self

    self.tabBarTemplate = CPTabBarTemplate(templates: generateTemplates(stationLists))
    tabBarTemplate?.delegate = self
    self.interfaceController?.setRootTemplate(self.tabBarTemplate!, animated: true, completion: nil)
  }

  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
    self.interfaceController = nil
    for observer in observers {
      observer.cancel()
    }
  }

  private func showNowPlayingTemplate(animated: Bool = true) {
    // #1
    guard interfaceController?.topTemplate != CPNowPlayingTemplate.shared else { return }

    if interfaceController?.templates.contains(CPNowPlayingTemplate.shared) == true {
      interfaceController?.pop(to: CPNowPlayingTemplate.shared, animated: animated, completion: nil)
    } else {
      interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: animated, completion: nil)
    }
  }

  public func cPListItemFrom(station: RadioStation) -> CPListItem {
      let listItem = CPListItem(text: station.name, detailText: station.desc, remoteImageUrl: URL(string: station.imageURL), placeholder: nil)
      listItem.handler = { _, completion in
        self.stationPlayer.play(station: station)
          completion()
      }
      return listItem
  }
}

extension CarPlaySceneDelegate: CPTabBarTemplateDelegate {
  func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
    print("User Switched Tabs")
  }
}

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
  func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
    print("templateWillAppear", aTemplate)
  }

  func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
    print("templateDidAppear", aTemplate)
  }

  func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    print("templateWillDisappear", aTemplate)
  }

  func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    print("templateDidDisappear", aTemplate)
  }
}
