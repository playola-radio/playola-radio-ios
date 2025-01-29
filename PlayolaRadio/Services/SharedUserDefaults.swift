//
//  SharedUserDefaults.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import IdentifiedCollections
import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var showSecretStations: Self {
        Self[.appStorage("showSecretStations"), default: false]
    }
}

extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<StationList>>.Default {
    static var stationLists: Self {
        Self[.fileStorage(dump(.documentsDirectory.appending(component: "station-lists.json"))), default: []]
    }
}

extension SharedKey where Self == InMemoryKey<Bool>.Default {
    static var stationListsLoaded: Self {
        Self[.inMemory("stationListsLoaded"), default: false]
    }
}

// extension SharedKey where Self == AppStorageKey<AppleSignInInfo?>.Default {
//  static var appleSignInInfo: Self {
//    Self[.appStorage("appleSignInInfo"), default: nil]
//  }
// }
extension SharedKey where Self == FileStorageKey<AppleSignInInfo?>.Default {
    static var appleSignInInfo: Self {
        Self[.fileStorage(dump(.documentsDirectory.appending(component: "apple-user.json"))), default: nil]
    }
}

extension SharedKey where Self == FileStorageKey<Auth>.Default {
    static var auth: Self {
        Self[.fileStorage(dump(.documentsDirectory.appending(component: "auth.json"))), default: Auth()]
    }
}
