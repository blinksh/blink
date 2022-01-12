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

import Purchases
import Combine
import SwiftUI

extension CompatibilityAccessManager.Entitlement {
  static let classic = Self("blink_shell_classic")
  static let plus = Self("blink_shell_plus")
}

class PurchasesUserModel: ObservableObject {
  @Published var classicAccess: EntitlementStatus = .inactive
  @Published var plusAccess: EntitlementStatus = .inactive
  @Published var errorMessage: String = ""
  
  @Published var plusProduct: SKProduct? = nil
  @Published var purchaseInProgress: Bool = false
  @Published var restoreInProgress: Bool = false
  
  private let _priceFormatter = NumberFormatter()
  
  private init() {
    _priceFormatter.numberStyle = .currency
    refresh()
  }
  
  static let shared = PurchasesUserModel()
  
  func refresh() {
    let manager = CompatibilityAccessManager.shared
    manager.status(of: .classic).assign(to: &$classicAccess)
    manager.status(of: .plus).assign(to: &$plusAccess)
    
    if self.plusProduct == nil {
      self.fetchPlusProduct()
    }
  }
  
  func restore() {
    Purchases.shared.restoreTransactions { info, error in
      
    }
  }
  
  func makePurchase(_ productId: String, successfulPurchase: @escaping () -> Void) {
    Purchases.shared.products([productId]) { products in
      guard let product = products.first else {
        return
      }
      
      Purchases.shared.purchaseProduct(product) { (transaction, purchaseInfo, error, cancelled) in
        guard error == nil, !cancelled else {
          return
        }
        
        self.refresh()
        successfulPurchase()
      }
    }
  }
  
  func purchasePlus() {
    guard let product = self.plusProduct else {
      return
    }
   
    withAnimation {
      self.purchaseInProgress = true
    }
    
    
    Purchases.shared.purchaseProduct(product) { (transaction, purchaseInfo, error, cancelled) in
      self.purchaseInProgress = false
    }
  }
  
  func restorePurchases() {
    self.restoreInProgress = true
    Purchases.shared.restoreTransactions { info, error in
      self.refresh()
      self.restoreInProgress = false
    }
  }
  
  func formattedPlustPriceWithPeriod() -> String? {
    guard let product = plusProduct else {
      return nil
    }
    
    _priceFormatter.locale = product.priceLocale
    guard let priceStr = _priceFormatter.string(for: product.price) else {
      return nil
    }
    
    guard let period = product.subscriptionPeriod else {
      return priceStr
    }
    
    let n = period.numberOfUnits
    
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
  
  func fetchPlusProduct() {
    Purchases.shared.products(["blink_shell_plus_1y_1999"]) { products in
      self.plusProduct = products.first
    }
  }
  
}

@objc public class PurchasesUserModelObjc: NSObject {

  @objc public static func preparePurchasesUserModel() {
    PurchasesUserModel.shared.refresh()
  }
}
