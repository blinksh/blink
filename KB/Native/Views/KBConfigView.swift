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

private func _row(_ key: KeyConfig) -> some View {
  DefaultRow(title: key.fullName, description: key.description) {
    KeyConfigView(key: key)
  }
}

private func _pairRow(_ pair: KeyConfigPair) -> some View {
  DefaultRow(title: pair.fullName, description: pair.description) {
    KeyConfigPairView(pair: pair)
  }
}

private func _bindingRow(_ binding: KeyBinding, title: String, last: String) -> some View {
  DefaultRow(title: title, description: binding.keysDescription(last)) {
    BindingConfigView(title: title, binding: binding)
  }
}

struct KBConfigView: View {
  @ObservedObject var config: KBConfig
  
  var body: some View {
    List() {
      Section(header: Text("Terminal")) {
        _row(config.capsLock)
        _pairRow(config.shift)
        _pairRow(config.control)
        _pairRow(config.option)
        _pairRow(config.command)
        _bindingRow(config.fnBinding,     title: "Functional Keys", last: "[0-9]")
        _bindingRow(config.cursorBinding, title: "Cursor Keys",     last: "[Arrow]")
      }
      Section(header: Text("Blink")) {
        DefaultRow(title: "Bindings") {
          BindingsConfigView(config: self.config)
        }
      }
    }
    .listStyle(GroupedListStyle())
    .navigationBarTitle("Keyboard")
    .onReceive(self.config.objectWillChange) { _ in
      DispatchQueue.main.async {
        SmarterTermInput.shared.saveAndApply(config: self.config)
      }
    }
  }
}

struct KBSettings_Previews: PreviewProvider {
  static var previews: some View {
    KBConfigView(config: KBConfig())
  }
}
