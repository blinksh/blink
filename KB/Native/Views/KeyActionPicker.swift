//
//  KeyActionPicker.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct KeyActionPicker: View {
  @Binding var action: KeyAction
  @State private var updatedAt = Date()
  
  var body: some View {
    List {
      Section {
        _action(title: "None",       value: .none)
        _action(title: "Escape",     value: .escape)
        _action(title: "Tab",        value: .tab)
        _action(title: "Ctrl Space", value: .ctrlSpace)
      }
    }.listStyle(GroupedListStyle())
  }
  
  private func _action(title: String, value: KeyAction) -> some View {
    HStack {
      Text(title)
      Spacer()
      Checkmark(checked: action == value)
    }.overlay(Button(action: {
      self.action = value
      self.updatedAt = Date()
    }, label: { EmptyView() } ))
  }
}

struct KeyActionPicker_Previews: PreviewProvider {
  static var previews: some View {
    KeyActionPicker(action: .constant(KeyAction.ctrlSpace))
  }
}
