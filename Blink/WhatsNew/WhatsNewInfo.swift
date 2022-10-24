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


class WhatsNewInfo {
  static var Prompt: String {
    "\u{1B}[30;48;5;45m New Blink \(Version)! \u{1B}[0m\u{1B}[38;5;45m\u{1B}[0m Check \"whatsnew\""
  }
  static private let MaxDisplayCount = 5
  static private let LastVersionKey = "LastVersionDisplay"
  static private let CountVersionDisplayKey = "CountVersionDisplayKey"
  static private var Version: String { UIApplication.blinkMajorVersion() }

  private init() {}

  static func mustDisplayVersionPrompt() -> Bool {
    let version = Version
    let defaults = UserDefaults.standard
    //defaults.set("", forKey: LastVersionKey)
    //defaults.set(0, forKey: CountVersionDisplayKey)

    let displayCount = defaults.integer(forKey: CountVersionDisplayKey)
    if let lastVersion = defaults.string(forKey: LastVersionKey) {
      return (version != lastVersion) && (displayCount < MaxDisplayCount)
    } else {
      return true
    }
  }

  static func versionPromptDisplayed() {
    let defaults = UserDefaults.standard

    let count = defaults.integer(forKey: CountVersionDisplayKey) + 1

    if count == MaxDisplayCount {
      setNewVersion()
    } else {
      defaults.set(count, forKey: CountVersionDisplayKey)
    }
  }
  
  static func setNewVersion() {
    let defaults = UserDefaults.standard

    defaults.set(Version, forKey: LastVersionKey)
    defaults.set(0, forKey: CountVersionDisplayKey)
  }
}
