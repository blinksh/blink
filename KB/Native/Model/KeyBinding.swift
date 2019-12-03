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

struct KeyToken: Identifiable {
  var keyCode: KeyCode?
  var loc: Int8 = 0
  var text: String = ""
  
  var label: String {
    if let code = keyCode {
      return code.symbol(loc: loc)
    }
    
    return text
  }
  
  var single: Bool {
    keyCode?.single == true
  }
  
  var id: String { text }
}

extension KeyToken: Comparable {
  static func < (lhs: KeyToken, rhs: KeyToken) -> Bool {
    if lhs.keyCode == nil && rhs.keyCode == nil {
      return lhs.text < rhs.text
    }
    
    if let left =  lhs.keyCode, let right = rhs.keyCode {
      return left.code < right.code
    }
    
    return lhs.keyCode != nil
  }
}

class KeyBinding: ObservableObject, Codable {
  var keys: Array<String> = []
  @Published var shiftLoc: Int8 = 0
  @Published var controlLoc: Int8 = 0
  @Published var optionLoc: Int8 = 0
  @Published var commandLoc: Int8 = 0
  
  @Published var action: KeyBindingAction = .command(.tabNew)
  
  func getTokens() -> [KeyToken] {
    var tokens: [KeyToken] = []
    for s in keys {
      var token = KeyToken()
      
      if let code = KeyCode(keyID: s) {
        token.keyCode = code
        switch code {
        case .shiftLeft, .shiftRight:
          token.loc = shiftLoc
        case .controlLeft, .controlRight:
          token.loc = controlLoc
        case .optionLeft, .optionRight:
          token.loc = optionLoc
        case .commandLeft, .commandRight:
          token.loc = commandLoc
        default:
          token.loc = 0
        }
        token.text = code.id
      } else {
        token.text = _keyName(s: s)
      }
      tokens.append(token)
    }
    
    return tokens.sorted()
  }
  
  func _keyName(s: String) -> String {
    var key = String(s.split(separator: "-").last ?? "?")
    key = key.replacingOccurrences(of: "Digit", with: "")
    key = key.replacingOccurrences(of: "Key", with: "")
    return key
  }
  
  func cycle(token: KeyToken) {
    guard let code = token.keyCode else {
      return
    }
    let loc = (token.loc + 1) % 3
    switch code {
      case .shiftLeft, .shiftRight:
        shiftLoc = loc
      case .controlLeft, .controlRight:
        controlLoc = loc
      case .optionLeft, .optionRight:
        optionLoc = loc
      case .commandLeft, .commandRight:
        commandLoc = loc
      default: break
    }
  }
  
  func keysDescription(_ last: String = "") -> String {
    let res = getTokens().map { $0.label }.joined(separator: "")
    if res.isEmpty {
      return res
    }
    return res + last
  }
  
  // - MARK: Codable
  
  init(
    keys: [String],
    shiftLoc: Int8,
    controlLoc: Int8,
    optionLoc: Int8,
    commandLoc: Int8,
    action: KeyBindingAction
  ) {
    self.keys = keys
    self.shiftLoc = shiftLoc
    self.controlLoc = controlLoc
    self.optionLoc = optionLoc
    self.commandLoc = commandLoc
    self.action = action
  }
  
  enum Keys: CodingKey {
    case keys
    case shiftLoc
    case controlLoc
    case optionLoc
    case commandLoc
    case action
  }
  
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    
    try c.encode(keys,         forKey: .keys)
    try c.encode(shiftLoc,     forKey: .shiftLoc)
    try c.encode(controlLoc,   forKey: .controlLoc)
    try c.encode(optionLoc,    forKey: .optionLoc)
    try c.encode(commandLoc,   forKey: .commandLoc)
    try c.encode(action,       forKey: .action)
  }
  
  required convenience init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    
    let keys        = try c.decode(Array<String>.self, forKey: .keys)
    let shiftLoc    = try c.decode(Int8.self, forKey: .shiftLoc)
    let controlLoc  = try c.decode(Int8.self, forKey: .controlLoc)
    let optionLoc   = try c.decode(Int8.self, forKey: .optionLoc)
    let commandLoc  = try c.decode(Int8.self, forKey: .commandLoc)
    let action      = try c.decode(KeyBindingAction.self, forKey: .action)
    
    self.init(
      keys: keys,
      shiftLoc: shiftLoc,
      controlLoc: controlLoc,
      optionLoc: optionLoc,
      commandLoc: commandLoc,
      action: action
    )
  }
  
  static var cmdC: KeyBinding {
    let keys: [String] = [
      KeyCode.commandLeft.id,
      "67:0-KeyC"
    ]
    
    return KeyBinding(keys: keys, shiftLoc: 0, controlLoc: 0, optionLoc: 0, commandLoc: 0, action: .command(.clipboardCopy))
  }
  
  static var cmdV: KeyBinding {
    let keys: [String] = [
      KeyCode.commandLeft.id,
      "68:0-KeyV"
    ]
    
    return KeyBinding(keys: keys, shiftLoc: 0, controlLoc: 0, optionLoc: 0, commandLoc: 0, action: .command(.clipboardPaste))
  }
}
