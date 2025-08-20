//
//  UserDefault.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/20/25.
//

import Foundation

private protocol AnyOptional {
  var isNil: Bool { get }
}

extension Optional: AnyOptional {
  var isNil: Bool { self == nil }
}

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
      if let optionalValue = newValue as? AnyOptional, optionalValue.isNil {
        storage.removeObject(forKey: key)
      } else {
        storage.set(newValue, forKey: key)
      }
    }
  }
}
