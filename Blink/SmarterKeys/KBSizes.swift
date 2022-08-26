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


import Foundation
import UIKit

// Little type helpers

fileprivate extension UIEdgeInsets {
  static var symbolSmall: Self { Self(top: 0, left: 0, bottom: 2, right: 0) }
  static var symbol:      Self { Self(top: 0, left: 0, bottom: 5, right: 0) }

  static var keySmall:    Self { Self(top: 3, left: 1, bottom: 1, right: 1) }
  static var key:         Self { Self(top: 5, left: 3, bottom: 6, right: 3) }
}

fileprivate extension CGFloat {
  static var symbolSmall: Self { 16 }
  static var symbol:      Self { 19 }

  static var textSmall: Self { 15 }
  static var text:      Self { 26 }

  static var cornerSmall: Self { 4 }
  static var corner:      Self { 6 }
  
  static var heightTiny:  Self { 38 }
  static var heightSmall: Self { 44 }
  static var height:      Self { 55 }
  static var heightMoreSpace:  Self { 67 }
  
  static var icon: Self { 48 }
}

struct KBSizes {
  typealias Insets = (key: UIEdgeInsets, symbol: UIEdgeInsets)
  typealias Fonts  = (text: CGFloat, symbol: CGFloat)
  typealias Widths = (icon: CGFloat, key: CGFloat, wide: CGFloat)
  
  typealias KB  = (height: CGFloat, padding: CGFloat, spacer: CGFloat)
  typealias Key = (fonts: Fonts, insets: Insets, corner: CGFloat, widths: Widths)

  fileprivate static let _fontsSmall: Fonts = (text: .textSmall, symbol: .symbolSmall)
  fileprivate static let _fonts:      Fonts = (text: .text,      symbol: .symbol)

  fileprivate static let _insetsSmall: Insets = (key: .keySmall, symbol: .symbolSmall)
  fileprivate static let _insets:      Insets = (key: .key,      symbol: .symbol)
  
  fileprivate static let _portraitPhoneKB: KB = (.heightSmall, padding: 0, spacer: 0)
  
  let kb: KB
  let key: Key
}

extension KBSizes {
  
  // MARK: Portrait iPhone sizes 📱
  
  static var portrait_iPhone_4: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 33, wide: 39)))
  }
  
  static var portrait_iPhone_4_7: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 33, wide: 39)))
  }
  
  static var portrait_iPhone_5_5: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 33, wide: 39)))
  }
  
  static var portrait_iPhone_5_8: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 33, wide: 39)))
  }
  
  static var portrait_iPhone_6_1: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 33, wide: 39)))
  }
  
  static var portrait_iPhone_6_5: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 33, wide: 39)))
  }
  
  static var portrait_iPhone_6_7: Self {
    Self(kb: _portraitPhoneKB, key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 34, wide: 40)))
  }
  
  // MARK: Portrait iPad sizes
  
  static var portrait_iPad_9_7: Self {
    Self(kb: (.height, padding: 3, spacer: 0), key: (_fonts, _insets, .corner, widths: (.icon, key: 55, wide: 66)))
  }
  
  static var portrait_iPad_10_5: Self {
    Self(kb: (.height, padding: 4, spacer: 0), key: (_fonts, _insets, .corner, widths: (.icon, key: 58, wide: 76)))
  }
  
  static var portrait_iPad_10_9: Self {
    Self(kb: (.height, padding: 6, spacer: 0), key: (_fonts, _insets, .corner, widths: (.icon, key: 56, wide: 82)))
  }
  
  static var portrait_iPad_11: Self {
    Self(kb: (.height, padding: 6, spacer: 0), key: (_fonts, _insets, .corner, widths: (.icon, key: 58, wide: 82)))
  }
  
  static var portrait_iPad_11_MoreSpace: Self {
    Self(kb: (.heightMoreSpace - 3.5, padding: 7, spacer: 2.5), key: (_fonts, _insets, .corner, widths: (.icon, key: 68, wide: 90)))
  }
  
  static var portrait_iPad_12_9: Self {
    Self(kb: (.height, padding: 1, spacer: 0), key: (_fonts, _insets, .corner, widths: (.icon, key: 64, wide: 79)))
  }
  
  // MARK: Landscape iPhone sizes  📱

  static var landscape_iPhone_4: Self {
    Self(kb: (.heightTiny, padding: 0, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 36, wide: 46)))
  }
  
  static var landscape_iPhone_4_7: Self {
    Self(kb: (.heightTiny, padding: 4, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 36, wide: 51.5)))
  }
  
  static var landscape_iPhone_5_5: Self {
    Self(kb: (.heightTiny, padding: 32, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 40, wide: 62.5)))
  }
  
  static var landscape_iPhone_5_8: Self {
    Self(kb: (.heightTiny, padding: 32, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 40, wide: 62.5)))
  }
  
  static var landscape_iPhone_6_1: Self {
    Self(kb: (.heightTiny, padding: 32, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 42, wide: 64)))
  }
  
  static var landscape_iPhone_6_5: Self {
    Self(kb: (.heightTiny, padding: 32, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 45, wide: 66.5)))
  }
  
  static var landscape_iPhone_6_7: Self {
    Self(kb: (.heightTiny, padding: 32, spacer: 0), key: (_fontsSmall, _insetsSmall, .cornerSmall, widths: (.icon, key: 47, wide: 68)))
  }
  
  // MARK: Landscape iPad Sizes
  
  static var landscape_iPad_9_7: Self {
    Self(kb: (.height, padding: 4, spacer: 0), key: (_fonts, _insets, .corner, widths: (.icon, key: 71, wide: 91)))
  }
  
  static var landscape_iPad_10_5: Self {
    Self(kb: (.height, padding: 4, spacer: 1), key: (_fonts, _insets, .corner, widths: (.icon, key: 74, wide: 96)))
  }
  
  static var landscape_iPad_10_9: Self {
    Self(kb: (.height, padding: 11.5, spacer: 6), key: (_fonts, _insets, .corner, widths: (.icon, key: 78.5, wide: 107)))
  }
  
  static var landscape_iPad_11: Self {
    Self(kb: (.height, padding: 11.5, spacer: 6.5), key: (_fonts, _insets, .corner, widths: (.icon, key: 79, wide: 108)))
  }
  
  static var landscape_iPad_11_MoreSpace: Self {
    Self(kb: (.heightMoreSpace, padding: 11.5, spacer: 7), key: (_fonts, _insets, .corner, widths: (.icon, key: 98, wide: 118)))
  }
  
  static var landscape_iPad_12_9: Self {
    Self(kb: (.height, padding: 1.5, spacer: 1), key: (_fonts, _insets, .corner, widths: (.icon, key: 80, wide: 100)))
  }
}

