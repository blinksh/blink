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

fileprivate func openLocationInFilesApp(location: BKSnippetDefaultLocation) {
  let path: String = { if location == .iCloud {
    return BlinkPaths.iCloudSnippetsLocationURL()!.relativePath
  } else {
    return BlinkPaths.localSnippetsLocationURL()!.relativePath
  } }()
  
  let fm = FileManager.default
  if !fm.fileExists(atPath: path) {
    try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
  }
  let actualURL = URL(string: "shareddocuments:/\(path)")!
  UIApplication.shared.open(actualURL)
}

struct SnippetsConfigView: View {
  @State var useBlinkIndex = !BLKDefaults.dontUseBlinkSnippetsIndex()
  @State var defaultStorage = BLKDefaults.snippetsDefaultLocation()
  @State var iCloudEnabled = FileManager.default.ubiquityIdentityToken != nil
  
  var body: some View {
    List {
      
      Section(
        header: Text("Locations"),
        footer: Text(iCloudEnabled ? "Open in [Files.app](https://files.app)" : "iCloud is disabled on this device.")
          .environment(\.openURL, OpenURLAction { url in
            openLocationInFilesApp(location: self.defaultStorage)
            return .discarded
          })
      ) {
        if iCloudEnabled {
          Picker(selection: $defaultStorage, label: Text("Default Location")) {
            Label("iCloud Drive", systemImage: "icloud")
            //            .labelStyle(.iconOnly)
              .tag(BKSnippetDefaultLocation.iCloud)
            Label(DeviceInfo.shared().onMyDevice(), systemImage: DeviceInfo.shared().deviceIcon())
            //            .labelStyle(.iconOnly)
              .tag(BKSnippetDefaultLocation.onDevice)
          }
        } else {
          HStack {
            Text("Default Location")
            Spacer()
            Label(DeviceInfo.shared().onMyDevice(), systemImage: DeviceInfo.shared().deviceIcon())
          }
        }
      }
      Section(
        header: Text("Sources"),
        footer: Text("Use public [collection](https://github.com/blinksh/snippets) of snippets. PRs are welcomed.")
      ) {
        Toggle("Blink Snips Index", isOn: $useBlinkIndex)
      }
    }
    .listStyle(GroupedListStyle())
    .navigationBarTitle("Snips")
    .onDisappear(perform: {
      BLKDefaults.setDontUseBlinkSnippetsIndex(!useBlinkIndex)
      BLKDefaults.setSnippetsDefaultLocation(defaultStorage)
      BLKDefaults.save()
    })
  }
}
