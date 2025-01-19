//
//  SharedUserDefaults.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var showSecretStations: Self {
    Self[.appStorage("showSecretStations"), default: false]
  }
}
