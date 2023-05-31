//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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

import Foundation
import SwiftUI
import BlinkSnippets

public struct SnippetView: View {
  var fuzzyMode: Bool
  var index: AttributedString
  var content: AttributedString
  var selected: Bool
  var snippet: Snippet
  var model: SearchModel
  
  public var body: some View {
    Button {
      self.model.onSnippetTap(snippet)
    } label: {
      VStack(alignment: .leading) {
        Text(index).font(.body).bold(fuzzyMode)
          .frame(maxWidth: .infinity, alignment: .leading).opacity(fuzzyMode ? 1.0 : 0.5)
        Text(content).font(.body).monospaced()
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .textSelection(.enabled)
      .padding(.all, 6)
      .background(
        .bar,
        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
      )
      .overlay {
        if selected {
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(lineWidth: 2).foregroundColor(.blue)
        }
      }
    }.buttonStyle(SnippetButtonStyle())
  }
}


struct SnippetButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.5 : 1)
  }
}
