//////////////////////////////////////////////////////////////////////////////////
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
//import Foundation
//import SwiftUI
////import Spinner
//
//struct PurchasePageView: Page {
//  @ObservedObject private var _model: PurchasesUserModel = .shared
//  
//  var horizontal: Bool
//  var switchTab: (_ idx: Int) -> ()
//  
//  init(horizontal: Bool, switchTab: @escaping (Int) -> ()) {
//    self.horizontal = horizontal
//    self.switchTab = switchTab
//  }
//  
//  var body: some View {
//    VStack(alignment: .leading) {
//      header()
//      Spacer().frame(maxHeight: horizontal ? 20 : 30)
//      rows()
//      Spacer().frame(maxHeight: horizontal ? 20 : 54)
//      HStack {
//        Spacer()
//        if _model.purchaseInProgress {
//          ProgressView()
//            .transition(.slide)
//        } else {
//          if let _ = _model.plusProduct {
//            Button("Subscribe now") {
//              _model.purchasePlus()
//            }
//            .buttonStyle(.borderedProminent)
//            .transition(
//              .scale.combined(with: .opacity).combined(with: .slide)
//            )
//            Spacer().frame(maxWidth: 40)
//          }
//          Button("get more free time") {
//            withAnimation {
//              switchTab(1)
//            }
//          }
//        }
//        Spacer()
//      }.frame(minHeight: 40)
//      Spacer()
//      if _model.restoreInProgress {
//        HStack {
//          Spacer()
//          ProgressView(label: { Text("restoring purchases....") })
//          Spacer()
//        }.padding(.bottom, self.horizontal ? 24 : 32)
//      } else {
//        HStack {
//          Spacer()
//          if let formattedPrice = _model.formattedPlusPriceWithPeriod() {
//            Text("Plan auto-renews for \(formattedPrice) until canceled.")
//              .font(.footnote)
//          }
//          Spacer()
//        }
//        Spacer().frame(maxHeight:8)
//        HStack {
//          Spacer()
//          Button("Privacy Policy", action: {
//            _model.openPrivacyAndPolicy()
//          }).padding(.trailing)
//          Button("Terms of Use", action: {
//            _model.openTermsOfUse()
//          }).padding(.trailing)
//          Button("Restore", action: {
//            _model.restorePurchases()
//          })
//          Spacer()
//        }
//        .font(.footnote)
//        .padding(.bottom, self.horizontal ? 32 : 40)
//      }
//      
//    }.padding()
//      .frame(maxWidth: horizontal ? 700 : 460)
//  }
//  
//  func header() -> some View {
//    Group {
//      Spacer()
//      Text( horizontal ? "It is Time to become a pro." : "It is Time\nto become a pro.")
//        .fontWeight(.bold)
//        .font(.largeTitle)
//      
//      Spacer().frame(maxHeight: horizontal ? 24 : 30)
//      
//      Text("Leverage Blink’s full power, and make it your all day companion.")
//        .font(.title2)
//    }
//  }
//  
//  func rows() -> some View {
//    GroupBox() {
//      if horizontal {
//        CheckmarkRow(text: "Access to all Blink.app features and Blink+ services")
//      } else {
//        CheckmarkRow(text: "Access to all Blink.app features")
//      }
//      Spacer().frame(maxHeight: 10)
//      CheckmarkRow(text: "Interruption free usage", checkedIcon: "infinity")
//      Spacer().frame(maxHeight: 10)
//      if !horizontal {
//        CheckmarkRow(text: "Early Access Blink+ features and services", checkedIcon: "plus")
//        Spacer().frame(maxHeight: 10)
//      }
//      CheckmarkRow(text: "Support Blink development", checkedIcon: "suit.heart.fill", iconColor: .red)
//    }
//  }
//}
