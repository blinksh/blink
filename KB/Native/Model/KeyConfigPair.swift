//
//  KeyConfigPair.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import Combine

class KeyConfigPair: ObservableObject, Codable {
  let left: KeyConfig
  let right: KeyConfig
  
  @Published var bothAsLeft: Bool {
    didSet {
      if bothAsLeft {
        right.up = left.up
        right.mod = left.mod
        right.down = left.down
      }
    }
  }
  
  init(left: KeyConfig, right: KeyConfig, bothAsLeft: Bool = true) {
    self.left = left
    self.right = right
    self.bothAsLeft = bothAsLeft
  }
  
  var fullName: String { left.fullName }
  
  var description: String {
    let leftDesc = left.description
    let rightDesc = right.description
    if bothAsLeft || leftDesc == rightDesc {
      return leftDesc
    }
    
    return "\(leftDesc); \(rightDesc)"
  }
  
  // - MARK: shortcuts
  
  static var shift: KeyConfigPair {
    KeyConfig(code: .shiftLeft, up: .none, down: .none, mod: .shift).pair(code: .shiftRight)
  }
  
  static var control: KeyConfigPair {
    KeyConfig(code: .controlLeft, up: .none, down: .none, mod: .control).pair(code: .controlRight)
  }
  
  static var option: KeyConfigPair {
    KeyConfig(code: .optionLeft, up: .none, down: .none, mod: .none).pair(code: .optionRight)
  }
  
  static var command: KeyConfigPair {
    KeyConfig(code: .commandLeft, up: .none, down: .none, mod: .none).pair(code: .commandRight)
  }
  
  // - MARK: Codable
  
  enum Keys: CodingKey {
    case left
    case right
    case same
  }
  
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    try c.encode(left,       forKey: .left)
    try c.encode(right,      forKey: .right)
    try c.encode(bothAsLeft, forKey: .same)
  }
  
  required convenience init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let left =       try c.decode(KeyConfig.self, forKey: .left)
    let right =      try c.decode(KeyConfig.self, forKey: .right)
    let bothAsLeft = try c.decode(Bool.self,      forKey: .same)
    self.init(left: left, right: right, bothAsLeft: bothAsLeft)
  }
}

