//
//  CarPlaySceneDelegate.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import CarPlay
import Combine
import FRadioPlayer
import IdentifiedCollections
import Sharing

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
    var stationPlayer: StationPlayer { StationPlayer.shared }

    override init() {
        super.init()
        setupNowPlayingTemplate()
    }

    private func playStation(_ station: RadioStation?) {
        guard let station else { return }
        stationPlayer.play(station: station)
        showNowPlayingTemplate()
    }

    private func sectionFromStations(_ stations: [RadioStation]) -> CPListSection {
        let listItems: [CPListItem] = stations.map { station in
            let listItem = self.cPListItemFrom(station: station)
            listItem.handler = { _, completion in
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
        stationLists
            .filter { $0.stations.count > 0 }
            .filter { $0.id != StationList.KnownIDs.inDevelopmentList.rawValue || showSecretStations == true }
            .map { templateFromStationList($0) }
    }

    func templateApplicationScene(_: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        trackingService.reportEvent(.carplayInitialized)
        $stationLists.publisher
            .sink { stationLists in
                let newTemplates = self.generateTemplates(stationLists)
                self.tabBarTemplate?.updateTemplates(newTemplates)
            }
            .store(in: &observers)

        self.interfaceController = interfaceController
        self.interfaceController?.delegate = self

        tabBarTemplate = CPTabBarTemplate(templates: generateTemplates(stationLists))
        tabBarTemplate?.delegate = self
        self.interfaceController?.setRootTemplate(tabBarTemplate!, animated: true, completion: nil)
    }

    func templateApplicationScene(_: CPTemplateApplicationScene, didDisconnectInterfaceController _: CPInterfaceController) {
        interfaceController = nil
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

    private func setupNowPlayingTemplate() {
//    MPNowPlayingSession
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
    func tabBarTemplate(_: CPTabBarTemplate, didSelect _: CPTemplate) {
        print("User Switched Tabs")
    }
}

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    func templateWillAppear(_ aTemplate: CPTemplate, animated _: Bool) {
        print("templateWillAppear", aTemplate)
    }

    func templateDidAppear(_ aTemplate: CPTemplate, animated _: Bool) {
        print("templateDidAppear", aTemplate)
    }

    func templateWillDisappear(_ aTemplate: CPTemplate, animated _: Bool) {
        print("templateWillDisappear", aTemplate)
    }

    func templateDidDisappear(_ aTemplate: CPTemplate, animated _: Bool) {
        print("templateDidDisappear", aTemplate)
    }
}
