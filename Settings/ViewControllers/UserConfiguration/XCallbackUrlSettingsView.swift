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

import SwiftUI

struct XCallbackUrlSettingsView: View {
  @State private var enabled: Bool
  @State private var key: String

  init() {
    // The key doubles as the shared secret, so a usable one has to exist before
    // the feature can be switched on.
    let key = BLKDefaults.xCallBackURLKey() ?? Self.generatedKey()
    _enabled = State(initialValue: BLKDefaults.isXCallBackURLEnabled())
    _key = State(initialValue: key)
  }

  var body: some View {
    List {
      Section(footer: Text(Self.footer(key: key))) {
        Toggle("Allow URL actions", isOn: $enabled)
        if enabled {
          HStack {
            Text("URL Key")
            Spacer()
            TextField("Required", text: Binding(
              get: { key },
              set: { key = Self.sanitize($0) }
            ))
              .multilineTextAlignment(.trailing)
              .autocapitalization(.none)
              .disableAutocorrection(true)
          }
        }
      }
    }
    .listStyle(.grouped)
    .navigationTitle("X Callback Url")
    .onDisappear {
      saveChanges()
    }
  }

  private func saveChanges() {
    // An empty key would accept every caller, so fall back to a fresh one.
    let key = self.key.isEmpty ? Self.generatedKey() : self.key
    BLKDefaults.setXCallBackURLKey(key)
    BLKDefaults.setXCallBackURLEnabled(enabled)
    BLKDefaults.save()
  }

  private static func generatedKey() -> String {
    String(ProcessInfo.processInfo.globallyUniqueString.prefix(6))
  }

  // ASCII alphanumerics only, so the key survives a URL query unencoded.
  private static func sanitize(_ value: String) -> String {
    String(value.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(100))
  }

  private static func footer(key: String) -> String {
    """
    Use x-callback-url for automation and inter-app communication. Your URL key \
    should be kept secret.

    Example:
    blinkshell://run?key=\(key.isEmpty ? "<URL key>" : key)&cmd=ls
    """
  }
}
