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

struct DisplaySettingsView: View {
  @State private var externalDisplayFontSize: CGFloat
  @State private var layoutModeIndex: Int
  @State private var projectionEnabled: Bool
  @State private var keycasts: Bool
  @State private var alternateAppIcon: Bool

  private var hasAppleSilicon: Bool {
    DeviceInfo.shared().hasAppleSilicon
  }

  init() {
    _externalDisplayFontSize = State(initialValue: CGFloat(BLKDefaults.selectedExternalDisplayFontSize()?.intValue ?? 24))
    let lm = BLKDefaults.layoutMode()
    _layoutModeIndex = State(initialValue: Self.layoutModeToIndex(lm))
    _projectionEnabled = State(initialValue: BLKDefaults.overscanCompensation() != .BKBKOverscanCompensationMirror)
    _keycasts = State(initialValue: BLKDefaults.isKeyCastsOn())
    _alternateAppIcon = State(initialValue: BLKDefaults.isAlternateAppIcon())
  }

  var body: some View {
    List {
      // -- Layout --
      Section {
        HStack {
          Text("Mode")
          Spacer()
          Picker("Mode", selection: $layoutModeIndex) {
            Text("Cover").tag(0)
            Text("Safe Fit").tag(1)
            if LayoutConstraintManager.supportsLayoutMode(.fill) {
              Text("Fill").tag(2)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .fixedSize()
        }
      } header: {
        Text("Layout")
      } footer: {
        VStack(alignment: .leading, spacing: 4) {
          Text("Cover — Terminal fills the screen, content may be clipped.")
          Text("Safe Fit — Honors safe area insets and layout guides.")
          Text("Fill — Stretches to fit the screen bounds.")
        }
      }

      // -- Keyboard --
      Section("Keyboard") {
        Toggle("Keycasts", isOn: $keycasts)
      }

      if !hasAppleSilicon {
        Section {
          Toggle("Air Terminals", isOn: $projectionEnabled)

          if projectionEnabled {
            HStack {
              Text("Font Size")
              Spacer()
              Text("\(Int(externalDisplayFontSize)) px")
                .foregroundColor(.secondary)
              Stepper("", value: $externalDisplayFontSize, in: 1...100, step: 1)
                .labelsHidden()
            }
          }
        } header: { Text("External Display") }
        footer: {
          Text("Projects a terminal to an external display that can be controlled from the main device. When disabled, the external display mirrors the device.")
        }
      }

      // -- App Icon --
      Section("App Icon") {
        Toggle("Alternate App Icon", isOn: $alternateAppIcon)
          .onChange(of: alternateAppIcon) { newValue in
            let iconName = newValue ? "DarkAppIcon" : nil
            UIApplication.shared.setAlternateIconName(iconName)
          }
      }
    }
    .listStyle(.grouped)
    .navigationTitle("Display")
    .onDisappear {
      saveChanges()
    }
  }

  private func saveChanges() {
    BLKDefaults.setExternalDisplayFontSize(NSNumber(value: Int(externalDisplayFontSize)))
    BLKDefaults.setLayoutMode(Self.layoutModeFromIndex(layoutModeIndex))
    if !hasAppleSilicon {
      BLKDefaults.setOversanCompensation(projectionEnabled ? .BKBKOverscanCompensationNone : .BKBKOverscanCompensationMirror)
    }
    BLKDefaults.setKeycasts(keycasts)
    BLKDefaults.setAlternateAppIcon(alternateAppIcon)
    BLKDefaults.save()
  }

  // Layout Mode: Cover=0, SafeFit=1, Fill=2
  private static func layoutModeToIndex(_ mode: BKLayoutMode) -> Int {
    switch LayoutConstraintManager.resolve(mode) {
    case .cover:   return 0
    case .safeFit: return 1
    case .fill:    return 2
    default:       return 0
    }
  }

  private static func layoutModeFromIndex(_ index: Int) -> BKLayoutMode {
    switch index {
    case 0: return .cover
    case 1: return .safeFit
    case 2: return .fill
    default: return .cover
    }
  }

}
