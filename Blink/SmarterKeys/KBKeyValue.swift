////////////////////////////////////////////////////////////////////////////////
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

import Foundation

enum KBKeyValue: Hashable, Identifiable, Codable {
  enum CodingKeys: CodingKey {
    case text
    case f
    case special
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    if let value: String = try container.decodeIfPresent(String.self, forKey: .text) {
      self = .text(value: value)
      return
    }
    
    if let value: Int8 = try container.decodeIfPresent(Int8.self, forKey: .f) {
      self = .f(value: value)
      return
    }
    
    if let id = try container.decodeIfPresent(String.self, forKey: .special),
      let keyType = Self.specials.first(where: { $0.id == id }) {
      self = keyType
      return
    }
    
    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Hmm"))
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .f(let value): try container.encode(value, forKey: .f)
    case .text(let value): try container.encode(value, forKey: .text)
    default: try container.encode(id, forKey: .special)
    }
  }
  
  case cmd
  case alt
  case ctrl
  case esc
  case tab
  case left
  case right
  case up
  case down
  case copy
  case paste
  case text(value: String)
  case f(value: Int8)
  
  var id: String {
    switch self {
    case .cmd:   return "cmd"
    case .tab:   return "tab"
    case .alt:   return "alt"
    case .ctrl:  return "ctrl"
    case .esc:   return "esc"
    case .left:  return "left"
    case .right: return "right"
    case .up:    return "up"
    case .down:  return "down"
    case .copy:  return "copy"
    case .paste: return "paste"
    case .text(let value): return value
    case .f(let value): return "F\(value)"
    }
  }
  
  var accessibilityLabel: String {
    // TODO: localize
    switch self {
    case .alt: return "Alternate"
    case .cmd: return "Command"
    case .copy: return "Copy"
    case .ctrl: return "Control"
    case .down: return "Down"
    case .esc: return "Escape"
    case .left: return "Left"
    case .right: return "Right"
    case .paste: return "Paste"
    case .tab: return "Tab"
    case .up: return "Up"
    case .text(let value): return value
    case .f(let value): return "F\(value)"
    }
  }
  
  var text: String {
    switch self {
    case .text(let value): return value
    default: return id
    }
  }
  
  var symbolName: String? {
    switch self {
    case .cmd:   return "command"
    case .tab:   return "arrow.right.to.line.alt"
    case .alt:   return "alt"
    case .ctrl:  return "control"
    case .esc:   return "escape"

    case .left:  return "arrow.left"
    case .right: return "arrow.right"
    case .up:    return "arrow.up"
    case .down:  return "arrow.down"

      
    case .copy:  return "doc.on.doc"
    case .paste: return "doc.on.clipboard"
    default:     return nil
    }
  }
  
  var alternateSymbolName: String? {
    switch self {
    case .left:  return "arrowtriangle.left.fill"
    case .right: return "arrowtriangle.right.fill"
    case .up:    return "arrowtriangle.up.fill"
    case .down:  return "arrowtriangle.down.fill"
    default: return nil
    }
  }
  
  static var specials: [Self] {
    [.cmd, .alt, .ctrl, .esc, .tab, .left, .right, .up, .down, .copy, .paste]
  }
  
  var isModifier: Bool {
    switch self {
    case .alt, .ctrl, .cmd: return true
    default: return false
    }
  }
  
}
