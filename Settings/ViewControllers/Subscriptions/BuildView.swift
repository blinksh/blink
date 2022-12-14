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

struct BuildRegionPickerView: View {
  @Binding var currentValue: BuildRegion
  @EnvironmentObject var nav: Nav
  
  var body: some View {
    List {
      Section() {
        ForEach(BuildRegion.all(), id: \.self) { value in
          HStack {
            value.full_title_label()
            Spacer()
            Checkmark(checked: currentValue == value)
          }
          .contentShape(Rectangle())
          .onTapGesture {
            currentValue = value
            nav.navController.popViewController(animated: true)
          }
        }
      }
    }
    .listStyle(InsetGroupedListStyle())
    .navigationTitle("Build Region")
  }
}


struct BuildView: View {
  
  @EnvironmentObject private var _nav: Nav
  @ObservedObject private var _model: PurchasesUserModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  @StateObject private var _viewModel = BuildViewModel()
  
  var body: some View {
    List {
      if _entitlements.earlyAccessFeatures.active == true {
        Section("Setup your build") {
          Row(
            content: {
              _viewModel.region.full_title_label()
            },
            details: {
              BuildRegionPickerView(currentValue: $_viewModel.region)
            }
          )
          Label {
            TextField(
              "Email for Notifications", text: $_viewModel.email
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .submitLabel(.next)
            .onSubmit {
              self._next()
            }
          } icon: {
            Image(systemName: "envelope")
          }
        }
      }
      
      if let _ = _model.plusProduct {
        
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
    .alert(errorMessage: $_model.alertErrorMessage)
    .navigationTitle("Blink Build")
    .toolbar {
      Button("Next") {
        self._next()
      }.disabled(!_viewModel.readyForPurchase())
    }
  }
  
  private func _next() {
//    let rootView = self.details().environmentObject(self.nav)
    let vc = UIHostingController(rootView: PurchaseBuildView(viewModel: _viewModel))
    _nav.navController.pushViewController(vc, animated: true)
  }
}

fileprivate struct PurchaseBuildView: View {
  @StateObject var viewModel: BuildViewModel;
  
  var body: some View {
    Button("Purchase") {
      Task {
        await viewModel.purchaseTask()
      }
    }
  }
}


fileprivate class BuildViewModel: ObservableObject {
  @Published var email: String = ""
  @Published var region: BuildRegion = BuildRegion.USEast0
  
  func readyForPurchase() -> Bool {
    email.contains("@")
  }
  
  func purchaseTask() async {
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
          FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
      return
    }

    do {
      let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
      
      let receiptB64 = receiptData.base64EncodedString(options: [])
      let revCatID = Purchases.shared.appUserID
      
      let params = [
        "email": self.email,
        "region": self.region.rawValue,
        "rev_cat_user_id": revCatID,
        "receipt_b64": receiptB64
      ]
      
      let json = try JSONSerialization.data(withJSONObject: params)
      
      var request = URLRequest(
        url: URL(string: "https://raw.api.blink.build/accounts/signup")!
      )
      request.httpMethod = "POST"
      request.httpBody = json
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      var (data, response) = try await URLSession.shared.data(for: request)
      
      print(data, response)
      
      
    }
    catch {
      print("error: " + error.localizedDescription)
    }
    
    
  }
}
