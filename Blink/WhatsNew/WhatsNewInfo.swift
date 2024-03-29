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
  // https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
  static private let defaults = UserDefaults.standard
  static private let MaxDisplayCount = 5
  static private let LastVersionKey = "LastVersionDisplay"
  static private let CountVersionDisplayKey = "CountVersionDisplayKey"
  static private var Version: String { UIApplication.blinkMajorVersion() }
  static private var prompt: String {
    "\u{1B}[30;48;5;45m New Blink \(Version)! \u{1B}[0m\u{1B}[38;5;45m\u{1B}[0m Check \"whatsnew\""
  }
  static private var firstUsagePrompt: String {
    """
\u{1B}[30;48;5;45m Type \u{1B}[0m\u{1B}[38;5;45m\u{1B}[0m
ssh, mosh - Connect to remote
code - Code session
build - Build dev environments
config - Hosts, keys, keyboard, etc...
help - Quick help
"""
  }

  private init() {}
  
  static func mustDisplayInitialPrompt() -> String? {
    if isFirstInstall() {
      promptDisplayed()
      return firstUsagePrompt
    }
    
    if mustDisplayVersionPrompt() {
      promptDisplayed()
      return prompt
    }
    
    return nil
  }
  
  static func setNewVersion() {
    defaults.set(Version, forKey: LastVersionKey)
    defaults.set(0, forKey: CountVersionDisplayKey)
  }
  
  static func isFirstInstall() -> Bool {
    defaults.value(forKey: LastVersionKey) == nil ? true : false
  }

  static private func mustDisplayVersionPrompt() -> Bool {
//    return true
    let version = Version
    //defaults.set("", forKey: LastVersionKey)
    //defaults.set(0, forKey: CountVersionDisplayKey)

    let displayCount = defaults.integer(forKey: CountVersionDisplayKey)
    if let lastVersion = defaults.string(forKey: LastVersionKey) {
      return (displayCount < MaxDisplayCount) && !versionsAreEqualIgnoringPatch(v1: version, v2: lastVersion)
    } else {
      return true
    }
  }
  
  static private func versionsAreEqualIgnoringPatch(v1: String, v2: String) -> Bool {
    v1.split(separator: ".").prefix(upTo: 2) == v2.split(separator: ".").prefix(upTo: 2)
  }

  static private func promptDisplayed() {
    let count = defaults.integer(forKey: CountVersionDisplayKey) + 1

    if count == MaxDisplayCount {
      setNewVersion()
    } else {
      defaults.set(count, forKey: CountVersionDisplayKey)
    }
  }
}
