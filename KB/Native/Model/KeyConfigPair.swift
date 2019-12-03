//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


import Combine

class KeyConfigPair: ObservableObject, Codable {
  @Published var left: KeyConfig
  @Published var right: KeyConfig
  
  var _cancellable = Set<AnyCancellable>()
  
  @Published var bothAsLeft: Bool {
    didSet {
      if bothAsLeft {
        _copyLeftToRight()
      }
    }
  }
  
  init(left: KeyConfig, right: KeyConfig, bothAsLeft: Bool = true) {
    self.left = left
    self.right = right
    self.bothAsLeft = bothAsLeft
    
    if bothAsLeft {
      _copyLeftToRight()
    }
    
    left.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &_cancellable)
    right.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &_cancellable)
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
  
  private func _copyLeftToRight() {
    right.up = left.up
    right.mod = left.mod
    right.down = left.down
    right.ignoreAccents = left.ignoreAccents
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
    var right = self.right
    if bothAsLeft {
      right = KeyConfig(code: right.code, up: left.up, down: left.down, mod: left.mod)
    }
    
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

