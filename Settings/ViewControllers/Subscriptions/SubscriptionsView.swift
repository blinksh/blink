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


struct SubscriptionsView: View {
  @EnvironmentObject var user: PurchasesUserModel
  @State private var showingOffering = false
  let dateFormatter = DateFormatter()
  
  init() {
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .short
  }
  var body: some View {
    VStack {
      Text("")
      /*
      Button(action: {
        let url = URL(string: "blinkv14://validateReceipt?originalUserId=\(Purchases.shared.appUserID)")!
        UIApplication.shared.open(url)
      }, label: { Text("Migrate") })
      if let plusAccess = user.plusAccess,
         plusAccess.active {
        Text("Thanks for subscribing")
        Text("Since: \(dateFormatter.string(from: plusAccess.since!))")
        Text("Until: \(dateFormatter.string(from: plusAccess.until!))")
        // TODO Manage subscription button?
      } else {
        if let classicAccess = user.classicAccess,
           classicAccess.active {
          Text("Thanks for your support. You can still upgrade.")
          Button(action: {
            showingOffering = true
          }, label: { Text("Upgrade") })
        } else {
          // Button to show the offering.
          Text("Not subscribed")
          Button(action: {
            showingOffering = true
          }, label: { Text("Subscribe") })
        }
      }
       */
    }
    // NOTE This was for testing. Real app should listen somewhere else.
    .onReceive(NotificationCenter.default.publisher(for: .subscriptionNag)) { _ in
      showingOffering = true
    }
//    .sheet(isPresented: $showingOffering, onDismiss: { SubscriptionNag.shared.restart() }) {
      Offering(isPresented: $showingOffering)
//    }
  }
}

struct Offering: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var user: PurchasesUserModel
  
  var body: some View {
    VStack {
      Button(action: {
        user.makePurchase("0000.0000", successfulPurchase: {
          print("Purchase successful")
          isPresented = false
        })
      }, label: {
        Text("Buy")
      })
      Button(action: {
        Purchases.shared.restoreTransactions { _, error in
          if let error = error {
            print("\(error)")
          }
          if PurchasesUserModel.shared.unlimitedTimeAccess.active {
            isPresented = false
          }
        }
      },
             label: { Text("Restore") })
    }
  }
  
}

