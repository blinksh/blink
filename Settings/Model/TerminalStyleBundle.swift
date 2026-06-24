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

struct TerminalStyleBundle: Codable {
  static let fileExtension = "blinkstyle"

  let style: TerminalStyle
  let embeddedThemeContent: String?
  let embeddedThemeName: String?
  let embeddedFontContent: String?
  let embeddedFontName: String?
  let exportDate: Date
  let blinkVersion: String?
}

// MARK: - Export

extension TerminalStyleBundle {
  private static func isDefaultResource(_ resource: BKResource?, of type: BKResource.Type) -> Bool {
    guard let resource = resource else { return false }
    return type.defaultResources()?.contains(where: { ($0 as? BKResource)?.name == resource.name }) ?? false
  }

  static func export(style: TerminalStyle) -> TerminalStyleBundle {
    // Themes: only embed if not a built-in default (no other categories for themes).
    let themeResource = BKTheme.withName(style.themeName)
    let embedTheme = themeResource != nil && !isDefaultResource(themeResource, of: BKTheme.self)

    // Fonts have three categories:
    // - Built-in defaults (ship with Blink) → don't embed
    // - System-wide monospace fonts (exist on device, BKFont.systemWide) → don't embed
    // - User-added custom fonts → embed
    let fontResource = BKFont(named: style.fontName)
    let embedFont = fontResource != nil
      && !isDefaultResource(fontResource, of: BKFont.self)
      && !(fontResource?.systemWide ?? true)

    return TerminalStyleBundle(
      style: style,
      embeddedThemeContent: embedTheme ? themeResource?.content() : nil,
      embeddedThemeName: embedTheme ? style.themeName : nil,
      embeddedFontContent: embedFont ? fontResource?.content() : nil,
      embeddedFontName: embedFont ? style.fontName : nil,
      exportDate: Date(),
      blinkVersion: UIApplication.blinkVersion()
    )
  }
}

// MARK: - Import

extension TerminalStyleBundle {
  enum ImportResult {
    case success(TerminalStyle)
    case alreadyExists(existing: TerminalStyle, incoming: TerminalStyle)
    case successWithWarnings(TerminalStyle, [String])
  }

  func importInto(store: TerminalStyleStore) -> ImportResult {
    // Check if a style with this UUID already exists
    if let existing = store.style(for: style.id) {
      return .alreadyExists(existing: existing, incoming: style)
    }

    var warnings: [String] = []

    // Install embedded theme if not already present
    if let themeName = embeddedThemeName,
       let themeContent = embeddedThemeContent {
      if BKTheme.withName(themeName) != nil {
        warnings.append("Theme '\(themeName)' already exists, using existing version.")
      } else if let data = themeContent.data(using: .utf8) {
        do {
          try BKTheme.save(themeName, withContent: data)
        } catch {
          warnings.append("Could not install theme '\(themeName)': \(error.localizedDescription)")
        }
      }
    }

    // Install embedded font if not already present
    if let fontName = embeddedFontName,
       let fontContent = embeddedFontContent {
      if BKFont.withName(fontName) != nil {
        warnings.append("Font '\(fontName)' already exists, using existing version.")
      } else if let data = fontContent.data(using: .utf8) {
        do {
          try BKFont.save(fontName, withContent: data)
        } catch {
          warnings.append("Could not install font '\(fontName)': \(error.localizedDescription)")
        }
      }
    }

    let added = store.addStyle(style)

    if warnings.isEmpty {
      return .success(added)
    }
    return .successWithWarnings(added, warnings)
  }
}

// MARK: - Serialization

extension TerminalStyleBundle {
  func encode() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  static func decode(from data: Data) throws -> TerminalStyleBundle {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(TerminalStyleBundle.self, from: data)
  }
}
