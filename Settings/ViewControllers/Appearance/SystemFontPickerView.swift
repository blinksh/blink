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
import UIKit

/// Picks an installed system font by name. The terminal refers to it via
/// `local()` CSS, so selection only sets the style's font name — nothing is stored.
struct SystemFontPickerView: View {
  let initialSelection: String
  let onSelect: (String) -> Void

  private enum Filter: Hashable {
    case monospaced
    case all
  }

  @State private var filter: Filter = .monospaced
  @State private var selection: String

  private let monospacedNames: [String]
  private let allNames: [String]

  init(initialSelection: String, onSelect: @escaping (String) -> Void) {
    self.initialSelection = initialSelection
    self.onSelect = onSelect
    self.monospacedNames = SystemFonts.monospaced
    self.allNames = SystemFonts.all
    _selection = State(initialValue: initialSelection)
  }

  private var names: [String] {
    filter == .monospaced ? monospacedNames : allNames
  }

  var body: some View {
    Form {
      Section {
        Picker("Show", selection: $filter) {
          Text("Monospaced").tag(Filter.monospaced)
          Text("All Fonts").tag(Filter.all)
        }
        .pickerStyle(.segmented)
      }

      if filter == .all {
        Section {
          Label {
            Text("Non-monospaced fonts may not align to the terminal grid, so columns and rows can look uneven.")
          } icon: {
            Image(systemName: "exclamationmark.triangle")
          }
          .font(.footnote)
          .foregroundColor(.secondary)
        }
      }

      Section {
        ForEach(names, id: \.self) { name in
          Button {
            selection = name
            onSelect(name)
          } label: {
            HStack {
              Text(name)
                .font(.custom(name, size: 17))
                .foregroundColor(.primary)
              Spacer()
              if selection == name {
                Image(systemName: "checkmark").foregroundColor(.accentColor)
              }
            }
          }
        }
      }
    }
    .navigationTitle("System Font")
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// The device's installed font catalog that feeds the picker.
enum SystemFonts {
  static var monospaced: [String] {
    // Descriptor matching can surface not selectable faces, so we filter only usable ones.
    let installed = Set(UIFont.familyNames)
    let traits: [UIFontDescriptor.TraitKey: Any] = [.symbolic: UIFontDescriptor.SymbolicTraits.traitMonoSpace.rawValue]
    let descriptor = UIFontDescriptor(fontAttributes: [.traits: traits])
    let matches = descriptor.matchingFontDescriptors(withMandatoryKeys: nil)
    var families = Set<String>()
    for match in matches {
      let family = UIFont(descriptor: match, size: 10).familyName
      if installed.contains(family) {
        families.insert(family)
      }
    }
    return families.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  static var all: [String] {
    UIFont.familyNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  static func contains(_ family: String) -> Bool {
    !family.isEmpty && UIFont.familyNames.contains(family)
  }
}
