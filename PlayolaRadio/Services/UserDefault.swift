//
//  UserDefault.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/20/25.
//

import Foundation

@propertyWrapper
struct UserDefault<Value> {
  let key: String
  let defaultValue: Value
  let storage: UserDefaults

  init(_ key: String, defaultValue: Value, storage: UserDefaults = .standard) {
    self.key = key
    self.defaultValue = defaultValue
    self.storage = storage
  }

  var wrappedValue: Value {
    get {
      return storage.object(forKey: key) as? Value ?? defaultValue
    }
    set {
      storage.set(newValue, forKey: key)
    }
  }
}
