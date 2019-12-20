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
    Group {
      Section(
        header: Text((title + " Press Send").uppercased()).font(.subheadline),
        footer: Text(key.press.usageHint).font(.footnote)) {
        Picker(selection: $key.press, label: Text("")) {
          Text("None").tag(KeyPress.none)
          Text("Escape").tag(KeyPress.escape)
          Text("Escape on Release").tag(KeyPress.escapeOnRelease)
        }
        .pickerStyle(SegmentedPickerStyle())
      }
      
      Section(
        header: Text((title + " As Modifier").uppercased()).font(.subheadline),
        footer: Text(key.mod.usageHint).font(.footnote)) {
        Picker(selection: $key.mod, label: Text("")) {
          Text("Default").tag(KeyModifier.none)
          Text("8-bit").tag(KeyModifier.bit8)
          Text("Ctrl").tag(KeyModifier.control)
          Text("Esc").tag(KeyModifier.escape)
          Text("Meta").tag(KeyModifier.meta)
          Text("Shift").tag(KeyModifier.shift)
        }
        .pickerStyle(SegmentedPickerStyle())
      }
      if key.code.hasAccents {
        Section(header: Text((title + " Accents").uppercased()).font(.subheadline)) {
          Toggle(isOn: self.$key.ignoreAccents, label: { Text("Ignore") })
        }
      }

    }
  }
}


struct KeySectionOld: View {
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
        Toggle(isOn: self.$key.ignoreAccents, label: { Text("Ignore Accents") })
      }
    }
  }
}
