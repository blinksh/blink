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
        Section(header: Text("Send")) {
          self._rowHex(action: self.action)
        }
        Section(header: Text("Press")) {
          ForEach(pressList, id: \.id) { ka in
            self._row(action: self.action, value: ka)
          }
        }
      }
      
    }
    .listStyle(GroupedListStyle())
  }
  
  private func _rowHex(action: KeyBindingAction) -> some View {
    var checked = false
    var value = ""
    if case .hex(let val, let comment) = action, comment == nil {
      checked = true
      value = val
    }
    return HStack {
      Text("Hex Code")
      Spacer()
      Checkmark(checked: checked)
    }.overlay(
      Button(action: {
        self.action = .hex(value, comment: nil)
        self.updatedAt = Date()
      }, label: { EmptyView() }
      )
    )
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

class HexFormatter: Formatter {
  private let _hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
  
  override func string(for obj: Any?) -> String? {
    guard let str = obj as? NSString
    else {
      return nil
    }
    return str.uppercased
  }
  
  override func editingString(for obj: Any) -> String? {
    if let str = obj as? NSString {
      return str as String
    }
    return nil
  }
  
  override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
    return partialString.isEmpty || partialString.rangeOfCharacter(from: _hexCharacterSet.inverted) == nil
  }
  
  override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
    obj?.pointee = hexString(str: string) as NSString
    return true
  }
  
  func hexString(str: String) -> String {
    String(
      str.replacingOccurrences(of: "[^0-9abcdef]", with: "", options: [.regularExpression, .caseInsensitive], range: nil)
        .uppercased()
        .prefix(1000)
    )
  }
}

struct HexEditorView: View {
  @ObservedObject var shortcut: KeyShortcut
  @State var value: String = ""
  private let _formatter = HexFormatter()
  
  var body: some View {
    TextField("HEX", value: $value, formatter: _formatter, onEditingChanged: { focused in
      self.shortcut.action = .hex(self._formatter.hexString(str: self.value), comment: nil)
    }) {
//      self.shortcut.action = .hex(self._formatter.hexString(str: self.value), comment: nil)
      }
    .disableAutocorrection(true)
    .keyboardType(.asciiCapable)
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
        Section(
          header: Text("Action"),
          footer: Text(self.shortcut.action.isCustomHEX ? "Use hex encoded sequence" : ""))
        {
          DefaultRow(title: shortcut.action.titleWithoutValue) {
            ActionsList(action: self.$shortcut.action, commandsMode: self.commandsMode)
          }
          if self.shortcut.action.isCustomHEX {
            HexEditorView(
              shortcut: self.shortcut,
              value: self.shortcut.action.hexValue
            )
          }
        }
      }
    .navigationBarItems(trailing:
      Button("Delete") {
        self.config.shortcuts.removeAll(where: { $0 === self.shortcut })
        self.nav.navController.popViewController(animated: true)
        self.config.touch()
      }
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
    let list = _list
    if list.isEmpty {
      return AnyView(_emptyView())
    } else {
      return AnyView(_tableView(list: list))
    }
  }
  
  private func _emptyView() -> some View {
    AnyView(VStack {
      Button("Add shortcut", action: _addAction)
    })
  }
  
  private func _tableView(list: [KeyShortcut]) -> some View {
    List {
      ForEach(list, id: \.id) { shortcut in
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
      trailing: Button("Add", action: _addAction)
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
