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

enum KBKeyShape: Hashable {
  // Compact sized button
  case icon(value: KBKeyValue)
  // Standart sized button
  case key(value: KBKeyValue)
  case wideKey(value: KBKeyValue)
  
  case flexKey(value: KBKeyValue)
  
  // Standart sized button with two values
  case vertical2(a: KBKeyValue, b: KBKeyValue)
  
  case arrows
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let value: KBKeyValue = try container.decodeIfPresent(KBKeyValue.self, forKey: .icon) {
      self = .icon(value: value)
      return
    }
    
    if let value: KBKeyValue = try container.decodeIfPresent(KBKeyValue.self, forKey: .key) {
      self = .key(value: value)
      return
    }
    
    if let value: KBKeyValue = try container.decodeIfPresent(KBKeyValue.self, forKey: .wideKey) {
      self = .wideKey(value: value)
      return
    }
    
    if container.contains(.arrows) {
      self = .arrows
      return
    }
    
    if let values = try container.decodeIfPresent([KBKeyValue].self, forKey: .vertical2),
      values.count == 2  {
      self = .vertical2(a: values[0], b: values[1])
      return
    }
    
    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Hmm"))
  }
}

extension KBKeyShape: Identifiable {
  var id: String {
    switch self {
    case .icon(let value): return "icon.\(value.id)"
    case .key(let value): return "key.\(value.id)"
    case .wideKey(let value): return "wideKey.\(value.id)"
    case .flexKey(let value): return "flexKey.\(value.id)"
    case .vertical2(let a, let b): return "vertical2.\(a.id),\(b.id)"
    case .arrows: return "arrows"
    }
  }
}

extension KBKeyShape {
  
  
  var primaryValue: KBKeyValue {
    switch self {
    case .icon(let value): return value
    case .key(let value): return value
    case .wideKey(let value): return value
    case .flexKey(let value): return value
    case .vertical2(let a, _): return a
    case .arrows: return .up
    }
  }
  
  var secondaryValue: KBKeyValue? {
    switch self {
    case .vertical2(_, let b): return b
    default: return nil
    }
  }
  
  var primaryText: String {
    primaryValue.text
  }
  
  var secondaryText: String? {
    switch self {
    case .vertical2(_, let b): return b.text
    default: return nil
    }
  }

}

extension KBKeyShape {
  enum CodingKeys: CodingKey {
    case icon
    case key
    case wideKey
    case flexKey
    case vertical2
    case triangle
    case arrows
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .icon(let value):
      try container.encode(value, forKey: .icon)
    case .key(let value):
      try container.encode(value, forKey: .key)
    case .wideKey(let value):
      try container.encode(value, forKey: .wideKey)
    case .flexKey(let value):
      try container.encode(value, forKey: .flexKey)
    case .vertical2(let a, let b):
      try container.encode([a, b], forKey: .vertical2)
    case .arrows:
      try container.encode(true, forKey: .arrows)
    }
    
  }
}
