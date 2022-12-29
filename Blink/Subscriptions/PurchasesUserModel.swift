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

import RevenueCat
import Combine
import SwiftUI

@MainActor
class PurchasesUserModel: ObservableObject {
  // MARK: products
  @Published var plusProduct: StoreProduct? = nil
  @Published var buildBasicProduct: StoreProduct? = nil
  @Published var classicProduct: StoreProduct? = nil
  
  // MARK: Progress indicators
  @Published var purchaseInProgress: Bool = false
  @Published var restoreInProgress: Bool = false
  
  // MARK: Migration states
  
  @Published var receiptIsVerified: Bool = false
  @Published var zeroPriceUnlocked: Bool = false
  @Published var receiptVerificationFailed = false
  @Published var dataCopied: Bool = false
  @Published var dataCopyFailed: Bool = false
  @Published var alertErrorMessage: String = ""
  @Published var migrationStatus: MigrationStatus = .validating
  
  
  // MARK: Blink Build states
  
  @Published var email: String = "" {
    didSet {
      emailIsValid = !email.isEmpty && _emailPredicate.evaluate(with: email)
    }
  }
  
  @Published var emailIsValid: Bool = false
  @Published var buildRegion: BuildRegion = BuildRegion.USEast0
  
  // MARK: Paywall
  
  @Published var paywallPageIndex: Int = 0
  
  private init() {
    refresh()
  }
  
  static let shared = PurchasesUserModel()
  
  func refresh() {
    
    if self.plusProduct == nil || self.classicProduct == nil || self.buildBasicProduct == nil {
      self.fetchProducts()
    }
  }

  func purchaseBuildBasic() async {
    guard let product = buildBasicProduct else {
      print("product should be loaded")
      return
    }
    
    guard emailIsValid else {
      alertErrorMessage = "Valid Email is Required"
      return
    }
    
    withAnimation {
      self.purchaseInProgress = true
    }
    
    defer {
      self.refresh()
      self.purchaseInProgress = false
    }
    
    do {
      let (_transaction, _info, canceled) = try await Purchases.shared.purchase(product: product)
      if canceled {
        return
      }
      
      guard let receiptB64 = Bundle.main.receiptB64() else {
        return
      }
      
      let revCatID = Purchases.shared.appUserID
      
      let json = try JSONSerialization.data(withJSONObject: [
        "email": self.email,
        "region": self.buildRegion.rawValue,
        "rev_cat_user_id": revCatID,
        "receipt_b64": receiptB64
      ])
      
      var request = URLRequest(
        url: URL(string: "https://raw.api.blink.build/application/signup")!
      )
      request.httpMethod = "POST"
      request.httpBody = json
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      var (data, response) = try await URLSession.shared.data(for: request)
      // 409 account exists
      // 200 ok
      
      guard let response = response as? HTTPURLResponse else {
        print("hmm")
        return
      }
      
      if response.statusCode == 200 {
        let obj = try JSONSerialization.jsonObject(with: data)
        var url = BlinkPaths.blinkBuildTokenURL()!
        try data.write(to: url)
      }
      
      
    } catch {
      self.alertErrorMessage = error.localizedDescription
    }
    
  }
  
  func purchasePlus() {
    _purchase(product: plusProduct)
  }
  
  func purchaseClassic() {
    _purchase(product: classicProduct)
  }
  
  private func getBuildAccessToken() async {
    do {
      
      guard let receiptB64 = Bundle.main.receiptB64() else {
        return
      }
      
      let json = try JSONSerialization.data(withJSONObject: [
        "receipt_b64": receiptB64
      ])
      
      var request = URLRequest(
        url: URL(string: "https://raw.api.blink.build/application/signin")!
      )
      
      request.httpMethod = "POST"
      request.httpBody = json
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      var (data, response) = try await URLSession.shared.data(for: request)
      // 409 account exists
      // 200 OK?
      
      guard let response = response as? HTTPURLResponse else {
        print("hmm")
        return
      }
      
      if response.statusCode == 200 {
        let obj = try JSONSerialization.jsonObject(with: data)
        var url = BlinkPaths.blinkBuildTokenURL()!
        try data.write(to: url)
      }

    } catch {
      
    }
  }
  
  private func _purchase(product: StoreProduct?) {
    guard let product = product else {
      return
    }
    withAnimation {
      self.purchaseInProgress = true
    }
    
    Purchases.shared.purchase(product: product) { (transaction, purchaseInfo, error, cancelled) in
      self.refresh()
      self.purchaseInProgress = false
    }
  }
  
  func restorePurchases() {
    self.restoreInProgress = true
    Purchases.shared.restorePurchases(completion: { info, error in
      self.refresh()
      self.restoreInProgress = false
      
      if EntitlementsManager.shared.build.active {
        
        Task {
          await self.getBuildAccessToken()
        }
        
      }
      
      if let error {
        self.alertErrorMessage = error.localizedDescription
      }
    })
  }
  
  func formattedPlusPriceWithPeriod() -> String? {
    plusProduct?.formattedPriceWithPeriod()
  }
  
  func formattedBuildPriceWithPeriod() -> String? {
    buildBasicProduct?.formattedPriceWithPeriod()
  }
  
  func fetchProducts() {
    Purchases.shared.getProducts([
      ProductBlinkShellClassicID,
      ProductBlinkShellPlusID,
      ProductBlinkBuildBasicID
    ]) { products in
      for product in products {
        let productID = product.productIdentifier
        
        if productID == ProductBlinkShellPlusID {
          self.plusProduct = product
        } else if productID == ProductBlinkShellClassicID {
          self.classicProduct = product
        } else if productID == ProductBlinkBuildBasicID {
          self.buildBasicProduct = product
        }
      }
    }
  }
  
  private lazy var _emailPredicate: NSPredicate = {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return NSPredicate(format:"SELF MATCHES %@", emailRegEx)
  }()
  
  enum MigrationStatus {
    case validating, accepted
    case denied(error: Error)
  }
  
}


// MARK: Migration
extension PurchasesUserModel {
  
  func startMigration() {
    migrationStatus = .validating
    let url = URL(string: "blinkv14://validatereceipt?originalUserId=\(Purchases.shared.appUserID)")!
    UIApplication.shared.open(url, completionHandler: { success in
      if success {
        self.alertErrorMessage = ""
      } else {
        self.alertErrorMessage = "Please install Blink 14 latest version first."
      }
    })
  }
  
  func continueMigrationWith(migrationToken: Data) {
    let originalUserId = Purchases.shared.appUserID

    do {
      let migrationToken = try JSONDecoder()
        .decode(MigrationToken.self, from: migrationToken)
      try migrationToken.validateReceiptForMigration(attachedTo: originalUserId)
      migrationStatus = .accepted
      receiptIsVerified = true
      zeroPriceUnlocked = true
      purchaseClassic()
    } catch {
      migrationStatus = .denied(error: error)
    }
  }
  
  func startDataMigration() {
    let url = URL(string: "blinkv14://exportdata?password=\(Purchases.shared.appUserID)")!
    UIApplication.shared.open(url, completionHandler: { success in
      if success {
        self.alertErrorMessage = ""
      } else {
        self.alertErrorMessage = "Please install Blink 14 latest version first."
      }
    })
  }
  
  func closeMigration() {
    NotificationCenter.default.post(name: .closeMigration, object: nil)
  }
  
}

// MARK: Open links
extension PurchasesUserModel {
  func openPrivacyAndPolicy() {
    blink_openurl(URL(string: "https://blink.sh/pp")!)
  }
  
  func openTermsOfUse() {
    blink_openurl(URL(string: "https://blink.sh/blink-gpl")!)
  }
  
  func openHelp() {
    blink_openurl(URL(string: "https://blink.sh/docs")!)
  }
  
  func openMigrationHelp() {
    blink_openurl(URL(string: "https://docs.blink.sh/migration")!)
  }
}


extension StoreProduct {

  func formattedPriceWithPeriod() -> String? {
//    priceFormatter.locale = priceLocale
//    guard let priceStr = priceFormatter.string(for: price) else {
//      return nil
//    }

    let priceStr = localizedPriceString
    guard let period = subscriptionPeriod else {
      return priceStr
    }

    let n = period.value

    if n <= 1 {
      switch period.unit {
      case .day: return "\(priceStr)/day"
      case .week: return "\(priceStr)/week"
      case .month: return "\(priceStr)/month"
      case .year: return "\(priceStr)/year"
      @unknown default:
        return priceStr
      }
    }

    switch period.unit {
    case .day: return "\(priceStr) / \(n) days"
    case .week: return "\(priceStr) / \(n) weeks"
    case .month: return "\(priceStr) / \(n) months"
    case .year: return "\(priceStr) / \(n) years"
    @unknown default:
      return priceStr
    }
  }
}


@objc public class PurchasesUserModelObjc: NSObject {
  
  @objc public static func preparePurchasesUserModel() {
    
    if !FeatureFlags.checkReceipt {
      configureRevCat()
      EntitlementsManager.shared.startUpdates()
      _ = PurchasesUserModel.shared
    }
  }
}

extension Bundle {
  func receiptB64() -> String? {
    guard let appStoreReceiptURL = self.appStoreReceiptURL,
          FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
      return nil
    }
    
    let receiptData = try? Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
    
    return receiptData?.base64EncodedString(options: [])
  }
}
