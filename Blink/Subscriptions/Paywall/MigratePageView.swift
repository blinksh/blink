////////////////////////////////////////////////////////////////////////////////
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

import Foundation
import SwiftUI

struct MigratePageView: Page {
  
  @ObservedObject private var _model: PurchasesUserModel = .shared
  
  var horizontal: Bool
  var switchTab: (_ idx: Int) -> ()
  
  init(horizontal: Bool, switchTab: @escaping (Int) -> ()) {
    self.horizontal = horizontal
    self.switchTab = switchTab
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      header()
      Spacer().frame(maxHeight: horizontal ? 20 : 30)
      rows()
      Spacer().frame(maxHeight: horizontal ? 20 : 54)
      HStack {
        Spacer()
        Button("Migrate", action: {
          NotificationCenter.default.post(name: .openMigration, object: nil)
        })
        .buttonStyle(.borderedProminent)
        Spacer()
      }
      Spacer()
      if _model.restoreInProgress {
        HStack {
          Spacer()
          ProgressView(label: { Text("restoring purchases....") })
          Spacer()
        }.padding(.bottom, self.horizontal ? 24 : 32)
      } else {
        HStack {
          Spacer()
          Text("Zero cost for Blink Shell 14 users.")
            .font(.footnote)
          Spacer()
        }
        Spacer().frame(maxHeight:8)
        HStack {
          Spacer()
          Button("Privacy Policy", action: {
            _model.openPrivacyAndPolicy()
          }).padding(.trailing)
          Button("Terms of Use", action: {
            _model.openTermsOfUse()
          }).padding(.trailing)
          Button("Restore", action: {
            _model.restorePurchases()
          })
          Spacer()
        }
        .font(.footnote)
        .padding(.bottom, self.horizontal ? 32 : 40)
      }
    }.padding()
      .frame(maxWidth: horizontal ? 700 : 460)
  }
  
  func header() -> some View {
    Group {
      Spacer()
      Text(self.horizontal ? "Migrate from Blink Shell 14" : "Migrate from\nBlink Shell 14 app")
        .fontWeight(.bold)
        .font(.largeTitle)
      
      Spacer().frame(maxHeight: horizontal ? 24 : 30)
      
      Text("Get grandfathered in the future of Blink. Unlock terminal features.")
        .font(.title2)
    }
  }
  
  func rows() -> some View {
    GroupBox() {
      CheckmarkRow(text: "All features from Blink Shell 14 app.")
      Spacer().frame(maxHeight: 10)
      CheckmarkRow(text: "Recieve updates and new features.")
      Spacer().frame(maxHeight: 10)
      CheckmarkRow(text: "Seamless usage. No interruptions.")
    }
  }
}
