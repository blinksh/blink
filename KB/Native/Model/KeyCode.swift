//
//  KeyCode.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

enum KeyCode: String, Codable {
  case escape       = "Escape"
  case capsLock     = "CapsLock"
  case shiftLeft    = "ShiftLeft"
  case shiftRight   = "ShiftRight"
  case controlLeft  = "ControlLeft"
  case controlRight = "ControlRight"
  case optionLeft   = "AltLeft"
  case optionRight  = "AltRight"
  case commandLeft  = "MetaLeft"
  case commandRight = "MetaRight"
  
  var isOption: Bool {
    switch self {
    case .optionLeft, .optionRight: return true
    case _: return false
    }
  }
  
  var hasAccents: Bool { isOption }
  
  var fullName: String {
    switch self {
    case .escape: return "⎋ Escape"
    case .capsLock: return "⇪ CapsLock"
    case .shiftLeft, .shiftRight: return "⇧ Shift"
    case .controlLeft, .controlRight: return "⌃ Control"
    case .optionLeft, .optionRight: return "⌥ Option"
    case .commandLeft, .commandRight: return "⌘ Command"
    }
  }
  
  var code: String { rawValue }
  
  var key: String {
    switch self {
    case .escape: return "Escape"
    case .capsLock: return "CapsLock"
    case .shiftLeft, .shiftRight: return "Shift"
    case .controlLeft, .controlRight: return "Control"
    case .optionLeft, .optionRight: return "Alt"
    case .commandLeft, .commandRight: return "Meta"
    }
  }
  
  var keyCode: Int {
    switch self {
    case .escape: return 27
    case .capsLock: return 20
    case .shiftLeft, .shiftRight: return 16
    case .controlLeft, .controlRight: return 17
    case .optionLeft, .optionRight: return 18
    case .commandLeft: return 91
    case .commandRight: return 93
    }
  }
  
  var location: Int {
    switch self {
    case .escape,
         .capsLock: return 0
    case .shiftLeft,
         .controlLeft,
         .optionLeft,
         .commandLeft: return 1
    case .shiftRight,
         .controlRight,
         .optionRight,
         .commandRight: return 2
    }
  }
    
  var keyId: String {
    "\(keyCode):\(code):\(location):\(key)"
  }
  
  // - MARK: Codable
  
  enum Keys: CodingKey {
    case keyCode
    case code
    case key
    case id
  }
  
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    try c.encode(keyCode,  forKey: .keyCode)
    try c.encode(code,  forKey: .code)
    try c.encode(key,   forKey: .key)
    try c.encode(keyId, forKey: .id)
  }
  
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let code  = try c.decode(String.self, forKey: .code)
    self.init(rawValue: code)!
  }
}
