//
//  KeyConfig.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import Combine
import Foundation

class KeyConfig: ObservableObject, Codable {
  let code: KeyCode
  @Published var up: KeyAction
  @Published var down: KeyAction
  @Published var mod: KeyModifier
  @Published var skipAccents: Bool
  
  init(code: KeyCode,
       up: KeyAction,
       down: KeyAction,
       mod: KeyModifier,
       skipAccents: Bool = true
  ) {
    self.code        = code
    self.up          = up
    self.down        = down
    self.mod         = mod
    self.skipAccents = skipAccents
  }
  
  func pair(right: KeyConfig) -> KeyConfigPair {
    KeyConfigPair(left: self, right: right, bothAsLeft: true)
  }
  
  func pair(code: KeyCode) -> KeyConfigPair {
    KeyConfigPair(
      left: self,
      right: KeyConfig(
        code: code,
        up: up,
        down: down,
        mod: mod,
        skipAccents: skipAccents
      )
    )
  }
  
  var fullName: String { code.fullName }
  
  var description: String {
    let upDesc = up.description
    let modDesc = mod.description
    let downDesc = down.description
    var res: [String] = []
    
    if !downDesc.isEmpty {
      res.append(downDesc)
    }
    
    if !modDesc.isEmpty {
      res.append("[\(modDesc)]")
    }
    
    if !upDesc.isEmpty {
      res.append(upDesc)
    }
    
    return res.joined(separator: ", ")
  }
  
  static var capsLock: KeyConfig {
    KeyConfig(code: .capsLock, up: .none, down: .none, mod: .none)
  }
  
  // - MARK: Codable
  
  enum Keys: CodingKey {
    case code
    case up
    case down
    case mod
    case skipAccents
  }
  
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    try c.encode(code,        forKey: .code)
    try c.encode(up,          forKey: .up)
    try c.encode(mod,         forKey: .mod)
    try c.encode(down,        forKey: .down)
    try c.encode(skipAccents, forKey: .skipAccents)
  }
  
  required convenience init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let code        = try c.decode(KeyCode.self,     forKey: .code)
    let up          = try c.decode(KeyAction.self,   forKey: .up)
    let down        = try c.decode(KeyAction.self,   forKey: .down)
    let mod         = try c.decode(KeyModifier.self, forKey: .mod)
    let skipAccents = try c.decode(Bool.self,        forKey: .skipAccents)
    self.init(code: code, up: up, down: down, mod: mod, skipAccents: skipAccents)
  }

}
