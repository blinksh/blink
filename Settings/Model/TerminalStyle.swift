////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2024 Blink Mobile Shell Project
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

struct TerminalStyle: Codable, Identifiable, Equatable {

  enum BoldMode: Int, Codable, CaseIterable {
    case auto = 0  // null — let terminal decide
    case on   = 1  // force bold
    case off  = 2  // disable bold
  }

  let id: UUID
  var name: String
  var themeName: String
  var fontName: String
  var fontSize: CGFloat
  var cursorBlink: Bool
  var boldMode: BoldMode
  var boldAsBright: Bool

  static let defaultFontName: String =
    Bundle.main.infoDictionary?["BLINK_APP_FONT"] as? String ?? "JetBrains Mono"

  static func makeBuiltInDefault() -> TerminalStyle {
    let fontSize: CGFloat = {
      #if targetEnvironment(macCatalyst)
      return 22
      #else
      if UIDevice.current.userInterfaceIdiom == .pad { return 18 }
      return 10
      #endif
    }()

    return TerminalStyle(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
      name: "Default",
      themeName: "Default",
      fontName: defaultFontName,
      fontSize: fontSize,
      cursorBlink: false,
      boldMode: .auto,
      boldAsBright: false
    )
  }
}

// MARK: - TermUIState

extension TermUIState {
  convenience init(style: TerminalStyle) {
    self.init()
    themeName = style.themeName
    fontName = style.fontName
    fontSize = Int(style.fontSize)
    enableBold = UInt(style.boldMode.rawValue)
    boldAsBright = style.boldAsBright
    cursorBlink = style.cursorBlink
  }
}

// MARK: - Resolved

extension TerminalStyle {
  struct Resolved {
    let style: TerminalStyle
    let themeContent: String?
    let fontContent: String?
    let fontFamily: String
    let isSystemFont: Bool
    let warnings: [Warning]

    enum Warning: Equatable {
      case themeNotFound(name: String)
      case fontNotFound(name: String)
    }

    var hasWarnings: Bool { !warnings.isEmpty }
  }

  func resolved() -> Resolved {
    var warnings: [Resolved.Warning] = []

    // Theme resolution
    let themeResource = BKTheme.withName(themeName)
    if themeResource == nil && themeName != "Default" {
      warnings.append(.themeNotFound(name: themeName))
    }
    let effectiveTheme = themeResource ?? BKTheme.withName("Default")
    let themeContent = effectiveTheme?.content()

    // Font resolution
    let fontResource = BKFont(named: fontName)
    if fontResource == nil {
      warnings.append(.fontNotFound(name: fontName))
    }

    let fallbackFont = BKFont(named: Self.defaultFontName)
    let effectiveFont = fontResource ?? fallbackFont
    let fontContent = effectiveFont?.content()
    let fontFamily = effectiveFont?.name ?? Self.defaultFontName
    let isSystemFont = effectiveFont?.systemWide ?? false

    return Resolved(
      style: self,
      themeContent: themeContent,
      fontContent: fontContent,
      fontFamily: fontFamily,
      isSystemFont: isSystemFont,
      warnings: warnings
    )
  }
}
