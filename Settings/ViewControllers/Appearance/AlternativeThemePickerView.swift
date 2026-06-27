////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2024 Blink Mobile Shell Project
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

/// Picks a style's alternative theme (or None). The preview applies the
/// highlighted theme over the rest of the base style's parameters; None previews
/// the primary theme.
struct AlternativeThemePickerView: View {
  let baseStyle: TerminalStyle
  let initialSelection: String?
  let onSelect: (String?) -> Void

  @State private var selection: String?
  @State private var revision: Int = 0

  private let themes: [BKTheme]

  init(baseStyle: TerminalStyle, initialSelection: String?, onSelect: @escaping (String?) -> Void) {
    self.baseStyle = baseStyle
    self.initialSelection = initialSelection
    self.onSelect = onSelect
    self.themes = (BKTheme.all() as? [BKTheme]) ?? []
    _selection = State(initialValue: initialSelection)
  }

  private var previewStyle: TerminalStyle {
    var style = baseStyle
    style.themeName = selection ?? baseStyle.themeName
    return style
  }

  var body: some View {
    VStack(spacing: 0) {
      TerminalPreviewCell(style: previewStyle, revision: revision)
        .frame(height: 200)

      List {
        Section {
          Button {
            select(nil)
          } label: {
            row(title: "None", isSelected: selection == nil)
          }

          ForEach(themes, id: \.name) { theme in
            Button {
              select(theme.name)
            } label: {
              row(title: theme.name, isSelected: selection == theme.name)
            }
          }
        }
      }
      .listStyle(.grouped)
    }
    .navigationTitle("Alternative Theme")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func row(title: String, isSelected: Bool) -> some View {
    HStack {
      Text(title).foregroundColor(.primary)
      Spacer()
      if isSelected {
        Image(systemName: "checkmark").foregroundColor(.accentColor)
      }
    }
  }

  private func select(_ name: String?) {
    selection = name
    revision += 1
    onSelect(name)
  }
}
