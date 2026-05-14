//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2025 Blink Mobile Shell Project
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
import ios_system
import SSH


/// Process-level environment that terminal sessions depend on: ios_system
/// bootstrap, the blink command list, process env vars, locale, libssh init.
enum TerminalEnvironment {

  // dispatch-once pattern
  private static let _configured: Void = {
    _initIOSSystem()
    _registerCommands()
    _setupProcessEnv()
  }()

  static func ensureConfigured() {
    _ = _configured
  }

  static func reloadProfileVars() {
    guard let path = BlinkPaths.blinkProfileFile(),
          let profile = try? String(contentsOfFile: path, encoding: .utf8)
    else {
      return
    }

    let whitespace = CharacterSet.whitespaces
    profile.enumerateLines { line, _ in
      var parts = line.components(separatedBy: "=")
      guard parts.count >= 2 else { return }

      let varName = parts.removeFirst().trimmingCharacters(in: whitespace)
      guard !varName.isEmpty else { return }

      var varValue = parts.joined(separator: "=").trimmingCharacters(in: whitespace)
      if varValue.hasPrefix("\"") || varValue.hasSuffix("\"") {
        let quoted = varValue
        // Drop the leading quote; a successful JSON-string parse overrides it.
        varValue = String(varValue.dropFirst())
        if let data = quoted.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
           let str = parsed as? String {
          varValue = str
        }
      }
      guard !varValue.isEmpty else { return }

      setenv(varName, varValue, 1)
    }
  }

  // MARK: - One-time steps

  private static func _initIOSSystem() {
    sideLoading = false  // disables ios_system's extra (non-blink) commands
    initializeEnvironment()
  }

  private static func _registerCommands() {
    // Must run after initializeEnvironment().
    guard let listPath = Bundle.main.path(forResource: "blinkCommandsDictionary", ofType: "plist") else {
      return
    }
    addCommandList(listPath)
  }

  private static func _setupProcessEnv() {
    let mainBundle = Bundle.main

    if let sslCertFile = mainBundle.path(forResource: "cacert", ofType: "pem") {
      setenv("SSL_CERT_FILE", sslCertFile, 1)
    }
    if let localesPath = mainBundle.path(forResource: "locales", ofType: "bundle") {
      setenv("PATH_LOCALE", localesPath, 1)
    }
    setlocale(LC_ALL, "UTF-8")
    setenv("TERM", "xterm-256color", 1)
    setenv("LANG", "en_US.UTF-8", 1)
    if let resourcePath = mainBundle.resourcePath {
      setenv("VIMRUNTIME", resourcePath + "/vim", 1)
    }

    if let homePath = BlinkPaths.homePath() {
      setenv("HOME", homePath, 1)
      setenv("SSH_HOME", homePath, 1)
      setenv("CURL_HOME", homePath, 1)
    }

    SSHInit()
  }
}
