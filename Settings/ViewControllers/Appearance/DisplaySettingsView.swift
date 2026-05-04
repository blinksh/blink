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
  @State private var overscanIndex: Int
  @State private var keyboardStyleIndex: Int
  @State private var keycasts: Bool
  @State private var alternateAppIcon: Bool

  private var hasAppleSilicon: Bool {
    DeviceInfo.shared().hasAppleSilicon
  }

  init() {
    _externalDisplayFontSize = State(initialValue: CGFloat(BLKDefaults.selectedExternalDisplayFontSize()?.intValue ?? 24))
    let lm = BLKDefaults.layoutMode()
    _layoutModeIndex = State(initialValue: Self.layoutModeToIndex(lm))
    _overscanIndex = State(initialValue: Int(BLKDefaults.overscanCompensation().rawValue))
    _keyboardStyleIndex = State(initialValue: Self.keyboardStyleToIndex(BLKDefaults.keyboardStyle()))
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

      // -- External Display --
      Section("External Display") {
        HStack {
          Text("Font Size")
          Spacer()
          Text("\(Int(externalDisplayFontSize)) px")
            .foregroundColor(.secondary)
          Stepper("", value: $externalDisplayFontSize, in: 1...100, step: 1)
            .labelsHidden()
        }

        HStack {
          Text("Overscan")
          Spacer()
          Picker("Overscan", selection: $overscanIndex) {
            Text("Scale").tag(0)
            Text("Inset").tag(1)
            Text("None").tag(2)
            Text(hasAppleSilicon ? "Stage" : "Mirror").tag(3)
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .fixedSize()
        }
      }

      // -- Keyboard --
      Section("Keyboard") {
        HStack {
          Text("Style")
          Spacer()
          Picker("Style", selection: $keyboardStyleIndex) {
            Text("System").tag(0)
            Text("Light").tag(1)
            Text("Dark").tag(2)
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .fixedSize()
        }

        Toggle("Keycasts", isOn: $keycasts)
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
    BLKDefaults.setOversanCompensation(BKOverscanCompensation(rawValue: overscanIndex) ?? .BKBKOverscanCompensationScale)
    BLKDefaults.setKeyboardStyle(Self.keyboardStyleFromIndex(keyboardStyleIndex))
    BLKDefaults.setKeycasts(keycasts)
    BLKDefaults.setAlternateAppIcon(alternateAppIcon)
    BLKDefaults.save()
    NotificationCenter.default.post(name: NSNotification.Name(BKAppearanceChanged), object: nil)
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

  // Keyboard Style: System=0, Light=1, Dark=2
  private static func keyboardStyleToIndex(_ style: BKKeyboardStyle) -> Int {
    switch style {
    case .system: return 0
    case .light:  return 1
    case .dark:   return 2
    default:      return 0
    }
  }

  private static func keyboardStyleFromIndex(_ index: Int) -> BKKeyboardStyle {
    switch index {
    case 0: return .system
    case 1: return .light
    case 2: return .dark
    default: return .system
    }
  }
}
