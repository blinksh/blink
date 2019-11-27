//
//  KeyModifierPicker.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct KeyModifierPicker: View {
  @Binding var modifier: KeyModifier
  @State private var updatedAt = Date()
  
  var body: some View {
    List {
      Section {
        _mod(title: "Default",     value: .none)
        _mod(title: "Escape",      value: .escape)
        _mod(title: "8-bit",       value: .bit8)
        _mod(title: "Control",     value: .control)
        _mod(title: "Shift",       value: .shift)
        _mod(title: "Meta",        value: .meta)
        _mod(title: "Meta Escape", value: .metaEscape)
      }
    }
    .listStyle(GroupedListStyle())
  }
  
  private func _mod(title: String, value: KeyModifier) -> some View {
    HStack {
      Text(title)
      Spacer()
      Checkmark(checked: modifier == value)
    }.overlay(Button(action: {
      self.modifier = value
      self.updatedAt = Date()
    }, label: { EmptyView() }))
  }
}

struct KeyModifierPicker_Previews: PreviewProvider {
  static var previews: some View {
    KeyModifierPicker(modifier: .constant(KeyModifier.bit8))
  }
}
