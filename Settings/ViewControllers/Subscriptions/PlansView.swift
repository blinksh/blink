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
  
  @State var alertErrorMessage: String = ""
  @ObservedObject var model: UserModel = .shared
  
  var body: some View {
    List {
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
        HStack {
          Text("This is your current plan").foregroundColor(.green)
        }
      }
      if let _ = model.plusProduct {
        Section(
          header: Text("Blink+ PLAN"),
          footer: Text("Plan auto-renews for \(model.formattedPlustPriceWithPeriod() ?? "") until canceled.")) {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
              Text("Access to all blink features and services")
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
              if model.purchaseInProgress {
                ProgressView()
              } else {
                Button("Upgrade to Blink+ Plan", action: {
                  model.purchasePlus()
                })
              }
            }
          }
      }
      
      Section(
        header: Text("Blink Classic PLAN"),
        footer: Text("After reciept verification with legacy `Blink.app` you will be able to access `basic plan` for zero cost purchase."),
        content: {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Access to all blink features you had in Blink Classic App")
          }
          HStack {
            Image(systemName: "infinity")
              .foregroundColor(.green)
            Text("Interruption free usage")
          }
          HStack {
            Button("Migrate from Blink Classic App", action: {
              let url = URL(string: "blinkv14://validateReceipt?originalUserId=\(Purchases.shared.appUserID)")!
              UIApplication.shared.open(url, completionHandler: { success in
                if success {
                  alertErrorMessage = ""
                } else {
                  alertErrorMessage = "Please install Blink 14 latest version first."
                }
              })
            })
          }.alert(errorMessage: $alertErrorMessage)
        }
      )
      Section {
        HStack {
          Button {

          } label: {
            Label("Restore Purchases", systemImage: "bag")
          }
        }
        HStack {
          Button {
            
          } label: {
            Label("Privacy Policy", systemImage: "link")
          }
        }
        HStack {
          Button {
            
          } label: {
            Label("Terms of Use", systemImage: "link")
          }
        }
      }
    }.navigationTitle("Subscription Plans")
  }
}

struct PlansView_Previews: PreviewProvider {
  static var previews: some View {
    PlansView()
  }
}
