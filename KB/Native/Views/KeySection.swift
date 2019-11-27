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


import SwiftUI

struct KeySection: View {
  var title: String = ""
  @ObservedObject var key: KeyConfig
  
  var body: some View {
    Section(header: Text(title)) {
      DefaultRow(title: "Down", description: key.down.description) {
        KeyActionPicker(action: self.$key.down).navigationBarTitle("Down Action")
      }
      DefaultRow(title: "Modifier", description: key.mod.description) {
        KeyModifierPicker(modifier: self.$key.mod).navigationBarTitle("Modifier")
      }
      DefaultRow(title: "Up", description: key.up.description) {
        KeyActionPicker(action: self.$key.up).navigationBarTitle("Up Action")
      }
      if key.code.hasAccents {
        Toggle(isOn: self.$key.skipAccents, label: { Text("Skip Accents") })
      }
    }
  }
}


struct KeySection_Previews: PreviewProvider {
  static var previews: some View {
    KeySection(title: "Test", key: KeyConfig.capsLock)
  }
}
