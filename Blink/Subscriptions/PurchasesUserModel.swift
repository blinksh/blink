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
  @Published var blinkShellPlusProduct: StoreProduct? = nil
  @Published var buildBasicProduct: StoreProduct? = nil
  @Published var classicProduct: StoreProduct? = nil
  @Published var blinkPlusBuildBasicProduct: StoreProduct? = nil
  @Published var blinkPlusProduct: StoreProduct? = nil
  
  @Published var blinkBuildTrial: IntroEligibility? = nil
  @Published var blinkPlusBuildTrial: IntroEligibility? = nil
  @Published var blinkPlusDiscount: IntroEligibility? = nil
  
  // MARK: Progress indicators
  @Published var purchaseInProgress: Bool = false
  @Published var restoreInProgress: Bool = false
  
  @Published var buildBasicTrialEligibility: IntroEligibility? = nil
  
  @Published var restoredPurchaseMessageVisible = false
  @Published var restoredPurchaseMessage = ""
  @Published var alertErrorMessage: String = ""
  
  var isBuildBasicTrialEligible: Bool {
    self.buildBasicTrialEligibility?.status == .eligible
  }

  
  private init() {
    refresh()
  }
  
  static let shared = PurchasesUserModel()
  
  func refresh() {
    BuildAccountModel.shared.checkBuildToken(animated: false)
    if self.blinkShellPlusProduct == nil
        || self.classicProduct == nil
        || self.buildBasicProduct == nil
        || self.blinkPlusBuildBasicProduct == nil {
      self.fetchProducts()
      self.fetchTrialEligibility()
    }
  }
  
  
  func purchaseBuildBasic() async {    
    guard let product = buildBasicProduct else {
      self.alertErrorMessage = "Product should be loaded"
      return
    }
    
    guard PublishingOptions.current.contains(.appStore) else {
      self.alertErrorMessage = "Available only in App Store"
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
      let (_, _, canceled) = try await Purchases.shared.purchase(product: product)
      if canceled {
        return
      }
      
      await BuildAccountModel.shared.trySignIn()
      withAnimation {
        self.purchaseInProgress = false
      }
    } catch {
      self.alertErrorMessage = error.localizedDescription
    }
  }
  
  func purchaseBlinkPlusBuildWithValidation(setupTrial: Bool) async {
    await _purchaseWithValidation(product: blinkPlusBuildBasicProduct, setupTrial: setupTrial)
  }
  
  func purchaseBlinkShellPlusWithValidation() async {
    await _purchaseWithValidation(product: blinkShellPlusProduct)
  }
  
  func purchaseBlinkPlusWithValidation() async {
    await _purchaseWithValidation(product: blinkPlusProduct)
  }

  func purchaseClassic() {
    _purchase(product: classicProduct)
  }
  
  func buildTrialAvailable() -> Bool {
    self.blinkBuildTrial?.status == IntroEligibilityStatus.eligible
  }
  
  func blinkPlusBuildTrialAvailable() -> Bool {
    blinkPlusBuildTrial?.status == IntroEligibilityStatus.eligible
  }

  func getUserID() -> String { Purchases.shared.appUserID }
  
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
  
  private func _purchaseWithValidation(product: StoreProduct?, setupTrial: Bool = false) async {
//    _purchase(product: product)
    if setupTrial {
      do {
        var notificationsAccepted = false
        switch product?.productIdentifier {
        case ProductBlinkPlusBuildBasicID:
          notificationsAccepted = try await TrialProgressNotification.OneWeek.setup()
        default:
          break
        }
        
        if !notificationsAccepted {
          EntitlementsManager.shared.keepShowingPaywall = false
          self.purchaseInProgress = false
          self.alertErrorMessage = "To continue, please accept or disable notifications for trial conversion."
          return
        }
      } catch {
        EntitlementsManager.shared.keepShowingPaywall = false
        self.purchaseInProgress = false
        self.alertErrorMessage = "Could not enable notifications - \(error.localizedDescription)"
        return
      }
    }
    
    do {
      self.purchaseInProgress = true
      EntitlementsManager.shared.keepShowingPaywall = true
      let res = try await Purchases.shared.restorePurchases()

      if EntitlementsManager.shared.build.active {
          await BuildAccountModel.shared.trySignIn();
      }

      if res.activeSubscriptions.contains(ProductBlinkShellPlusID) {
        self.restoredPurchaseMessage = "We have restored your subscription to Blink+.\nThanks for your support!"
        self.restoredPurchaseMessageVisible = true
        self.purchaseInProgress = false
        return
      }
      if res.activeSubscriptions.contains(ProductBlinkPlusBuildBasicID) {
        self.restoredPurchaseMessage = "We have restored your subscription to Blink+Build.\nThanks for your support!"
        self.restoredPurchaseMessageVisible = true
        self.purchaseInProgress = false
        return
      }
    } catch {
      if let error = error as? RevenueCat.ErrorCode,
         error == .missingReceiptFileError {
        // Ignore the error and continue with purchase
        print("Missing Receipt File Error - continue with purchase")
      } else {
        EntitlementsManager.shared.keepShowingPaywall = false
        self.purchaseInProgress = false
        self.alertErrorMessage = error.localizedDescription
        return
      } 
    }

    EntitlementsManager.shared.keepShowingPaywall = false
    _purchase(product: product)
  }
  
  func restorePurchases() {
    self.restoreInProgress = true
    EntitlementsManager.shared.keepShowingPaywall = false
    Purchases.shared.restorePurchases(completion: { info, error in
      self.refresh()
      self.restoreInProgress = false
      if let error {
        self.alertErrorMessage = error.localizedDescription
        return
      }
      
      if EntitlementsManager.shared.build.active {
        Task {
          await BuildAccountModel.shared.trySignIn();
        }
      }
    })
  }
  
  func formattedPlusPriceWithPeriod() -> String? {
    blinkShellPlusProduct?.formattedPriceWithPeriod()
  }
  
  func formattedBuildPriceWithPeriod() -> String? {
    buildBasicProduct?.formattedPriceWithPeriod()
  }
  
  func formattedBlinkPlusBuildPriceWithPeriod() -> String? {
    blinkPlusBuildBasicProduct?.formattedPriceWithPeriod()
  }
  
  func formattedBlinkPlusPriceWithPeriod() -> String? {
    blinkPlusProduct?.formattedPriceWithPeriod()
  }
  
  func fetchProducts() {
    Purchases.shared.getProducts([
      ProductBlinkShellClassicID,
      ProductBlinkShellPlusID,
      ProductBlinkBuildBasicID,
      ProductBlinkPlusBuildBasicID,
      ProductBlinkPlusID
    ]) { products in
      DispatchQueue.main.async {
        for product in products {
          let productID = product.productIdentifier
          
          if productID == ProductBlinkShellPlusID {
            self.blinkShellPlusProduct = product
          } else if productID == ProductBlinkShellClassicID {
            self.classicProduct = product
          } else if productID == ProductBlinkBuildBasicID {
            self.buildBasicProduct = product
          } else if productID == ProductBlinkPlusBuildBasicID {
            self.blinkPlusBuildBasicProduct = product
          } else if productID == ProductBlinkPlusID {
            self.blinkPlusProduct = product
          }
        }
      }
    }
  }
  
  func fetchTrialEligibility() {
    Purchases.shared.checkTrialOrIntroDiscountEligibility(
      productIdentifiers: [
        ProductBlinkBuildBasicID,
        ProductBlinkPlusBuildBasicID,
        ProductBlinkPlusID],
      completion: { map in
        DispatchQueue.main.async {
          self.blinkBuildTrial = map[ProductBlinkBuildBasicID]
          self.blinkPlusBuildTrial = map[ProductBlinkPlusBuildBasicID]
          self.blinkPlusDiscount = map[ProductBlinkPlusID]
        }
      })
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

extension StoreProductDiscount {
  func formattedPriceWithPeriod() -> String? {
//    priceFormatter.locale = priceLocale
//    guard let priceStr = priceFormatter.string(for: price) else {
//      return nil
//    }

    let priceStr = localizedPriceString
    let period = self.subscriptionPeriod

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
    configureRevCat()
    EntitlementsManager.shared.startUpdates()
    _ = PurchasesUserModel.shared
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
