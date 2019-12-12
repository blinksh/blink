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

struct ActionsList: View {
  @Binding var action: KeyBindingAction
  var commandsMode: Bool
  @State private var updatedAt = Date()
  
  var pressList = KeyBindingAction.pressList
  var commandList = KeyBindingAction.commandList
  
  var body: some View {
    List {
      if commandsMode {
        Section(header: Text("Commands")) {
          ForEach(commandList, id: \.id) { ka in
            self._row(action: self.action, value: ka)
          }
        }
      } else {
        Section(header: Text("Press")) {
          ForEach(pressList, id: \.id) { ka in
            self._row(action: self.action, value: ka)
          }
        }
      }
      
    }
    .listStyle(GroupedListStyle())
  }
  
  private func _row(action: KeyBindingAction, value: KeyBindingAction) -> some View {
    HStack {
      Text(value.title)
      Spacer()
      Checkmark(checked: action.id == value.id)
    }.overlay(
      Button(action: {
        self.action = value
        self.updatedAt = Date()
      }, label: { EmptyView() }
      )
    )
  }
}

struct ShortcutConfigView: View {
  @EnvironmentObject var nav: Nav
  @ObservedObject var config: KBConfig
  @ObservedObject var shortcut: KeyShortcut
  var commandsMode: Bool
  
  var body: some View {
    List {
      Section(
        header: Text("Combination"),
        footer: Text("Press keys on external KB to change.")
      ) {
        HStack {
          Text(shortcut.description)
        }
      }
      Section(header: Text("Action")) {
        DefaultRow(title: shortcut.action.title) {
          ActionsList(action: self.$shortcut.action, commandsMode: self.commandsMode)
        }
      }
    }
    .navigationBarItems(trailing:
      Button(
        action: {
          self.config.shortcuts.removeAll(where: { $0 === self.shortcut })
          self.nav.navController.popViewController(animated: true)
          self.config.touch()
        },
        label: { Text("Delete") }
      )
    )
    .listStyle(GroupedListStyle())
    .background(KeyCaptureView(shortcut: shortcut))
    .onReceive(shortcut.objectWillChange, perform: config.objectWillChange.send)
  }
}

struct ShortcutsConfigView: View {
  @EnvironmentObject var nav: Nav
  @ObservedObject var config: KBConfig
  var commandsMode: Bool
  
  var body: some View {
    List {
      ForEach(_list, id: \.id) { shortcut in
        DefaultRow(title: shortcut.title, description: shortcut.description) {
          ShortcutConfigView(
            config: self.config,
            shortcut: shortcut,
            commandsMode: self.commandsMode
          )
        }
      }
      .onDelete(perform: _onDelete)
    }
    .listStyle(GroupedListStyle())
    .navigationBarItems(
      trailing: Button(
        action: _addAction,
        label: { Text("Add") }
      )
    )
  }
  
  private func _addAction() {
    let action: KeyBindingAction = commandsMode ? KeyBindingAction.command(.clipboardCopy) : .none
    let shortcut = KeyShortcut(action: action, modifiers: [], input: "")
    config.shortcuts.append(shortcut)
    config.touch()
    let rootView = ShortcutConfigView(
      config: config,
      shortcut: shortcut,
      commandsMode: commandsMode
    ).environmentObject(nav)
    let vc = UIHostingController(rootView: rootView)
    nav.navController.pushViewController(vc, animated: true)
  }
  
  private var _list: [KeyShortcut] {
    config
      .shortcuts
      .filter({$0.action.isCommand == commandsMode})
      .sorted(by: {$0.title < $1.title})
  }
  
  private func _onDelete(offsets: IndexSet) {
    let list = self._list
    var toDelete: [KeyShortcut] = []
    for idx in offsets {
      toDelete.append(list[idx])
    }
    for v in toDelete {
      self.config.shortcuts.removeAll(where: {$0 === v})
    }
  }
}
