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
import Purchases

struct PlansView: View {
  
//  @State var alertErrorMessage: String = ""
  @ObservedObject private var _model: PurchasesUserModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  
  var body: some View {
    List {
      if _entitlements.unlimitedTimeAccess.active == false {
        Section("Free Plan") {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Access to all Blink features")
          }
          HStack {
            Image(systemName: "timer")
              .foregroundColor(.orange)
            Text("30 minutes time limit")
          }
          HStack {
            Text("This is your current plan").foregroundColor(.green)
          }
        }
      }
      if let _ = _model.plusProduct {
        Section(
          header: Text("Blink+ PLAN"),
          footer: Text("Plan auto-renews for \(_model.formattedPlusPriceWithPeriod() ?? "") until canceled.")) {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
              Text("Access to all Blink features and services")
            }
            HStack {
              Image(systemName: "suit.heart.fill")
                .foregroundColor(.red)
              Text("Support Blink development")
            }
            HStack {
              Image(systemName: "infinity")
                .foregroundColor(.green)
              Text("Interruption free usage")
            }
            HStack {
              if _model.purchaseInProgress {
                ProgressView()
              } else {
                if _entitlements.activeSubscriptions.contains(ProductBlinkShellPlusID) {
                  Text("This is your current plan").foregroundColor(.green)
                } else {
                  Button("Upgrade to Blink+ Plan", action: {
                    _model.purchasePlus()
                  })
                }
              }
            }
          }
      }
      
      Section(
        header: Text("Blink Classic PLAN"),
        footer: Text("After receipt verification with legacy `Blink.app` you will be able to access `classic plan` for zero cost purchase."),
        content: {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Access to all Blink features you had in Blink Shell 14 App")
          }
          HStack {
            Image(systemName: "infinity")
              .foregroundColor(.green)
            Text("Interruption free usage")
          }
          HStack {
            if _entitlements.nonSubscriptionTransactions.contains(ProductBlinkShellClassicID) {
              Text("Blink Classic Unlocked").foregroundColor(.green)
            } else {
              Button("Migrate from Blink Shell 14 App", action: {
                NotificationCenter.default.post(name: .openMigration, object: nil)
              })
            }
          }
        }
      )
      if _entitlements.unlimitedTimeAccess.active == true {
        Section("Free Plan") {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Access to all blink features")
          }
          HStack {
            Image(systemName: "timer")
              .foregroundColor(.orange)
            Text("30 minutes time limit")
          }
        }
      }
      Section {
        HStack {
          if _model.restoreInProgress {
            ProgressView()
            Text("restoring purchases....").padding(.leading, 10)
          } else {
            Button {
              _model.restorePurchases()
            } label: {
              Label("Restore Purchases", systemImage: "bag")
            }
          }
        }
        HStack {
          Button {
            _model.openPrivacyAndPolicy()
          } label: {
            Label("Privacy Policy", systemImage: "link")
          }
        }
        HStack {
          Button {
            _model.openTermsOfUse()
          } label: {
            Label("Terms of Use", systemImage: "link")
          }
        }
      }
    }
    .disabled(_model.purchaseInProgress || _model.restoreInProgress)
    .navigationTitle("Subscription Plans")
  }
}
