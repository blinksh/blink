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

extension BKAgentForward: Hashable {
  var label: String {
    switch self {
    case BKAgentForwardNo: return "No"
    case BKAgentForwardConfirm: return "Confirm"
    case BKAgentForwardYes: return "Always"
    case _: return ""
    }
  }
  
  var hint: String {
    switch self {
    case BKAgentForwardNo: return "Do not forward the agent"
    case BKAgentForwardConfirm: return "Confirm each use of a key"
    case BKAgentForwardYes: return "Forward all keys always"
    case _: return ""
    }
  }

  static var all: [BKAgentForward] {
    [
      BKAgentForwardNo,
      BKAgentForwardConfirm,
      BKAgentForwardYes,
    ]
  }
}

struct AgentForwardPromptPickerView: View {
  @Binding var currentValue: BKAgentForward

  var body: some View {
    List {
      Section(footer: Text(currentValue.hint)) {
        ForEach(BKAgentForward.all, id: \.self) { value in
          HStack {
            Text(value.label).tag(value)
            Spacer()
            Checkmark(checked: currentValue == value)
          }
          .contentShape(Rectangle())
          .onTapGesture { currentValue = value }
        }
      }
    }
    .listStyle(InsetGroupedListStyle())
    .navigationTitle("Agent Forwarding")
  }
}
