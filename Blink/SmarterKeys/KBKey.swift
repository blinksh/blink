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

import UIKit

struct KBKey: Hashable {
  let shape: KBKeyShape
  private let _traits: KBTraits
  
  init(_ type: KBKeyShape, traits: KBTraits) {
    self.shape = type
    _traits = traits
  }
  
  func match(traits: KBTraits) -> Bool {
    traits.isSubset(of: _traits)
  }
  
  func view(keyDelegate: KBKeyViewDelegate) -> KBKeyView {
    switch shape {
    case .icon:      return KBKeyViewSymbol(key: self, keyDelegate: keyDelegate)
    case .key:       return KBKeyViewSymbol(key: self, keyDelegate: keyDelegate)
    case .wideKey:   return KBKeyViewSymbol(key: self, keyDelegate: keyDelegate)
    case .flexKey:   return KBKeyViewFlexible(key: self, keyDelegate: keyDelegate)
    case .vertical2: return KBKeyViewVertical2(key: self, keyDelegate: keyDelegate)
    case .arrows:    return KBKeyViewArrows(key: self, keyDelegate: keyDelegate)
    }
  }
  
  static func icon(_ value: KBKeyValue, traits: KBTraits) -> Self {
    Self(.icon(value: value), traits: traits)
  }
  
  static func key(_ value: KBKeyValue, traits: KBTraits) -> Self {
    Self(.key(value: value), traits: traits)
  }
  
  static func wideKey(_ value: KBKeyValue, traits: KBTraits) -> Self {
    Self(.wideKey(value: value), traits: traits)
  }
  
  static func vertical2(_ a: String, _ b: String, traits: KBTraits) -> Self {
    .vertical2(.text(value: a), .text(value: b), traits: traits)
  }
  
  static func vertical2(_ a: KBKeyValue, _ b: KBKeyValue, traits: KBTraits) -> Self {
    Self(.vertical2(a: a, b: b), traits: traits)
  }
  
  static func flexKey(_ value: KBKeyValue, traits: KBTraits) -> Self {
    Self(.flexKey(value: value), traits: traits)
  }
  
  static func arrows(traits: KBTraits) -> Self {
    Self(.arrows, traits: traits)
  }
  
  var isFlexible: Bool {
    switch shape {
    case .flexKey: return true
    default: return false
    }
  }
}

extension KBKey: Identifiable {
  var id: String { shape.id }
}

extension KBKey {
  var sound: KBSound {
    switch shape.primaryValue {
    case .text: return .text
    default: return .modifier
    }
  }
}

extension KBKey {
  var isModifier: Bool {
    switch shape.primaryValue {
    case .cmd, .alt, .ctrl: return true
    default: return false
    }
  }
}
