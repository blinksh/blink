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

fileprivate struct CardRow: View {
  let key: BKPubKey
  let isChecked: Bool
  
  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(key.id)
        Text(key.keyType ?? "").font(.footnote)
      }.contentShape(Rectangle())
      Spacer()
      Checkmark(checked: isChecked)
    }.contentShape(Rectangle())
  }
}

struct KeyPickerView: View {
  @Binding var currentKey: [String]
  @EnvironmentObject private var _nav: Nav
  @State private var _list: [BKPubKey] = BKPubKey.all()
  let multipleSelection: Bool
  
  var body: some View {
    List {
      HStack {
        Text("None")
        Spacer()
        Checkmark(checked: currentKey.isEmpty)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        _selectKey("")
      }
      ForEach(_list, id: \.tag) { key in
        CardRow(key: key, isChecked: currentKey.contains { key.id == $0 })
          .onTapGesture {
            _selectKey(key.id)
          }
      }
    }
    .listStyle(InsetGroupedListStyle())
    .navigationTitle("Select a Key")
  }
  
  private func _selectKey(_ key: String) {
    if multipleSelection {
      if key.isEmpty {
        currentKey = []
      } else if let idx = currentKey.firstIndex(of: key) {
        currentKey.remove(at: idx)
      } else {
        currentKey.append(key)
      }
    } else {
      if key.isEmpty {
        currentKey = []
      } else {
        currentKey = [key]
      }
      _nav.navController.popViewController(animated: true)
    }
  }
}
