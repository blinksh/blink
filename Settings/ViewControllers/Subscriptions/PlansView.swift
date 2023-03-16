////////////////////////////////////////////////////////////////////////////////////
////
//// B L I N K
////
//// Copyright (C) 2016-2019 Blink Mobile Shell Project
////
//// This file is part of Blink.
////
//// Blink is free software: you can redistribute it and/or modify
//// it under the terms of the GNU General Public License as published by
//// the Free Software Foundation, either version 3 of the License, or
//// (at your option) any later version.
////
//// Blink is distributed in the hope that it will be useful,
//// but WITHOUT ANY WARRANTY; without even the implied warranty of
//// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//// GNU General Public License for more details.
////
//// You should have received a copy of the GNU General Public License
//// along with Blink. If not, see <http://www.gnu.org/licenses/>.
////
//// In addition, Blink is also subject to certain additional terms under
//// GNU GPL version 3 section 7.
////
//// You should have received a copy of these additional terms immediately
//// following the terms and conditions of the GNU General Public License
//// which accompanied the Blink Source Code. If not, see
//// <http://www.github.com/blinksh/blink>.
////
//////////////////////////////////////////////////////////////////////////////////
//
//
//import SwiftUI
//import RevenueCat
//
//struct PlansView: View {
//  
//  @ObservedObject private var _model: PurchasesUserModel = .shared
//  @ObservedObject private var _entitlements: EntitlementsManager = .shared
//  @Namespace private var nspace;
//  
//  var body: some View {
//    List {
//<<<<<<< Updated upstream
//=======
////      if _entitlements.unlimitedTimeAccess.active == false {
////        Section("Free Plan") {
////          Label {
////            Text("Access to all Blink.app features")
////          } icon: {
////            Image(systemName: "checkmark.circle.fill")
////              .foregroundColor(.green)
////
////          }
////          Label {
////            Text("Subscription nags 3x day max")
////          } icon: {
////            Image(systemName: "timer")
////              .foregroundColor(.orange)
////
////          }
////          HStack {
////            Text("This is your current plan").foregroundColor(.green)
////          }
////        }
////      }
//>>>>>>> Stashed changes
//      if let _ = _model.plusProduct {
//        Section(
//          header: Text("Blink+ PLAN"),
//          footer: Text("Plan auto-renews for \(_model.formattedPlusPriceWithPeriod() ?? "") until canceled.")) {
//            Label {
//              Text("Access to all Blink.app features")
//            } icon: {
//              Image(systemName: "checkmark.circle.fill")
//                .foregroundColor(.green)
//            }
//            Label {
//              Text("Interruption free usage")
//            } icon: {
//              Image(systemName: "infinity")
//                .foregroundColor(.green)
//            }
//            Label {
//              Text("Early Access Blink+ features and services")
//            } icon: {
//              Image(systemName: "plus")
//                .foregroundColor(.green)
//            }
//            Row(content: {
//              Label {
//                Text("Blink Build Beta")
//              } icon: {
//                Image(systemName: "hammer.circle")
//                  .foregroundColor(.green)
//              }
//            }) {
//              BasicMachinePlanView(nspace: nspace, showClose: false)
//            }
//            Label {
//              Text("Support Blink development")
//            } icon: {
//              Image(systemName: "suit.heart.fill")
//                .foregroundColor(.red)
//            }
//            HStack {
//              if _model.purchaseInProgress {
//                ProgressView()
//              } else {
//                if _entitlements.activeSubscriptions.contains(ProductBlinkShellPlusID) {
//                  Text("This is your current plan").foregroundColor(.green)
//                } else {
//                  Button("Upgrade to Blink+ Plan", action: {
//                    _model.purchasePlus()
//                  })
//                }
//              }
//            }
//          }
//      }
//      if true { //_entitlements.nonSubscriptionTransactions.contains(ProductBlinkShellClassicID) {
//        Section(
//          header: Text("Blink Classic PLAN"),
//          footer: Text(""),
//          content: {
//            Label {
//              Text("Access to all Blink.app features")
//            } icon: {
//              Image(systemName: "checkmark.circle.fill")
//                .foregroundColor(.green)
//            }
//            Label {
//              Text("Interruption free usage")
//            } icon: {
//              Image(systemName: "infinity")
//                .foregroundColor(.green)
//            }
//            Label {
//              Text("Zero cost lifetime purchase")
//            } icon: {
//              Image(systemName: "bag")
//                .foregroundColor(.green)
//            }
//            
//            HStack {
//              Text("Blink Classic Unlocked").foregroundColor(.green)
//            }
//          }
//        )
//      }
//      
//      Section {
//        HStack {
//          Button {
//            _model.openPrivacyAndPolicy()
//          } label: {
//            Label("Privacy Policy", systemImage: "link")
//          }
//        }
//        HStack {
//          Button {
//            _model.openTermsOfUse()
//          } label: {
//            Label("Terms of Use", systemImage: "link")
//          }
//        }
//      }
//    }
//    .disabled(_model.purchaseInProgress || _model.restoreInProgress)
//    .alert(errorMessage: $_model.alertErrorMessage)
//    .navigationTitle("Subscription Plans")
//  }
//}
