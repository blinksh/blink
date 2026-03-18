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
import UIKit

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
  @Published var blinkPlusIntroOffer: IntroEligibility? = nil

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
    refreshProducts()
  }

  static let shared = PurchasesUserModel()

  private func refreshProducts() {
    if self.blinkShellPlusProduct == nil
        || self.classicProduct == nil
        || self.buildBasicProduct == nil
        || self.blinkPlusBuildBasicProduct == nil {
      self.fetchProducts()
      self.fetchTrialEligibility()
    }
  }

  private func refreshTokens() {
    BuildAccountModel.shared.checkBuildToken(animated: false)
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
      BuildAccountModel.shared.checkBuildToken(animated: false)
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

  func purchaseBlinkPlusWithTrialValidation(setupTrial: Bool) async -> Bool {
    let duration: TrialDuration = setupTrial ? .twoWeeks : .no
    
    return await _purchaseWithTrialValidation(product: blinkPlusProduct, setupTrialDuration: duration)
  }

  // func purchaseClassic() {
  //   _purchase(classicProduct)
  // }

  func buildTrialAvailable() -> Bool {
    self.blinkBuildTrial?.status == IntroEligibilityStatus.eligible
  }

  func blinkPlusBuildTrialAvailable() -> Bool {
    blinkPlusBuildTrial?.status == IntroEligibilityStatus.eligible
  }

  func blinkPlusIntroOfferAvailable() -> Bool {
    blinkPlusIntroOffer?.status == IntroEligibilityStatus.eligible
  }

  func getUserID() -> String { Purchases.shared.appUserID }

  private func _purchase(_ product: StoreProduct) async -> Bool {
    do {
      let result = try await Purchases.shared.purchase(product: product)
      if result.userCancelled {
        return false
      }
      return true
    } catch {
      self.alertErrorMessage = "Purchase cannot be completed. Please try again. Details: \(error.localizedDescription)"
      return false
    }
  }

  private func _setupTrialProgressNotification(_ progress: TrialProgressNotification, didPromptSettings: Bool = false) async -> Bool {
    switch await TrialProgressNotification.ensureNotificationsReady() {
    case .ready:
      do {
        try await progress.setup()
        return true
      } catch {
        self.alertErrorMessage = "Couldn’t schedule trial reminders — retry or disable reminders."
        return false
      }

    case .needsSettings:
      // Offer to open Settings once; avoid looping if user declines or keeps it disabled.
      if didPromptSettings {
        self.alertErrorMessage = "Notifications are still off. You can enable them later in Settings or disable trial reminders."
        return false
      }
      let opened = await promptOpenSettings(
        title: "Enable Notifications?",
        message: "Notifications are off. Turn them on in Settings or disable trial reminders."
      )
      if opened { await waitUntilAppBecomesActive() }

      return await _setupTrialProgressNotification(progress, didPromptSettings: true)

    case .unknown(let msg):
      // Offer to open Settings once; avoid looping if user declines or keeps it disabled.
      if didPromptSettings {
        self.alertErrorMessage = "Notifications are still off. You can enable them later in Settings or disable trial reminders."
        return false
      }
      let opened = await promptOpenSettings(
        title: "Enable Notifications?",
        message: "Notifications are off. Turn them on in Settings or disable trial reminders. Details: \(msg)"
      )
      if opened { await waitUntilAppBecomesActive() }

      return await _setupTrialProgressNotification(progress, didPromptSettings: true)
    }
  }

  private func _purchaseWithTrialValidation(product: StoreProduct?, setupTrialDuration: TrialDuration = .no) async -> Bool {
    guard let product = product else {
      self.alertErrorMessage = "No valid products selected"
      return false
    }

    withAnimation {
      self.purchaseInProgress = true
    }

    defer {
      self.purchaseInProgress = false
    }

    if let notification: TrialProgressNotification = switch setupTrialDuration {
    case .no:
      nil
    case .oneWeek:
      TrialProgressNotification.OneWeek
    case .twoWeeks:
      TrialProgressNotification.TwoWeeks
    case .oneMonth:
      TrialProgressNotification.OneMonth
    } {
      let success = await _setupTrialProgressNotification(notification)
      if !success {
        return false
      }
    }

    return await _purchase(product)
  }
  
  // MARK: - Friendly helpers

  @MainActor
  private func promptOpenSettings(title: String, message: String) async -> Bool {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    var open = false
    await withCheckedContinuation { cont in
      alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in open = false; cont.resume() })
      alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in open = true; cont.resume() })
      topVC()?.present(alert, animated: true)
    }
    if open, let url = URL(string: UIApplication.openSettingsURLString),
       UIApplication.shared.canOpenURL(url) { await UIApplication.shared.open(url) }
    return open
  }

  @MainActor
  private func waitUntilAppBecomesActive() async {
    await withCheckedContinuation { cont in
      var token: NSObjectProtocol?
      token = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
        if let t = token { NotificationCenter.default.removeObserver(t) }
        cont.resume()
      }
    }
  }

  private func topVC(
    base: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first?.rootViewController
  ) -> UIViewController? {
    if let nav = base as? UINavigationController { return topVC(base: nav.visibleViewController) }
    if let tab = base as? UITabBarController { return topVC(base: tab.selectedViewController) }
    if let presented = base?.presentedViewController { return topVC(base: presented) }
    return base
  }

  @MainActor
  private func friendlyMessage(for error: Error) -> String {
    return "Could not enable notifications — \(error.localizedDescription)"
  }

  func restoreActiveAppSubscriptions(alertIfNone: Bool) async -> Bool {
    await _restorePurchases()

    if EntitlementsManager.shared.hasActiveSubscriptions() {
      self.restoredPurchaseMessage = "We have restored your subscriptions. Thanks for your support!"
      self.restoredPurchaseMessageVisible = true
      return true
    } else {
      if alertIfNone {
        self.alertErrorMessage = "Could not find an active subscription. Please contact us if you are having trouble."
      }
      return false
    }
  }
  
  func restoreBlinkPlusEntitlements(alertIfNone: Bool) async -> Bool {
    await _restorePurchases()
    
    if EntitlementsManager.shared.earlyAccessFeatures.active,
       EntitlementsManager.shared.unlimitedTimeAccess.active {
      self.restoredPurchaseMessage = "We have restored your subscriptions. Thanks for your support!"
      self.restoredPurchaseMessageVisible = true
      return true
    } else {
      if alertIfNone {
        self.alertErrorMessage = "Could not find a valid purchase for Blink Plus."
      }
      return false
    }
  }
  
  func restoreBlinkBuildEntitlements(alertIfNone: Bool) async -> Bool {
    await _restorePurchases()
    
    if EntitlementsManager.shared.build.active {
      self.restoredPurchaseMessage = "We have restored your subscriptions. Thanks for your support!"
      self.restoredPurchaseMessageVisible = true
      return true
    } else {
      if alertIfNone {
        self.alertErrorMessage = "Could not find Blink Build entitlements in your subscription."
      }
      return false
    }
  }
  
  private func _restorePurchases() async {
    self.restoreInProgress = true

    defer {
      self.refreshTokens()
      self.restoreInProgress = false
    }

    do {
      let _ = try await Purchases.shared.restorePurchases()

      if EntitlementsManager.shared.build.active {
        await BuildAccountModel.shared.trySignIn()
      }
    } catch {
      self.alertErrorMessage = error.localizedDescription
    }
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

  private func fetchProducts() {
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

  private func fetchTrialEligibility() {
    Purchases.shared.checkTrialOrIntroDiscountEligibility(
      productIdentifiers: [
        ProductBlinkBuildBasicID,
        ProductBlinkPlusBuildBasicID,
        ProductBlinkPlusID
      ],
      completion: { map in
        DispatchQueue.main.async {
          self.blinkBuildTrial = map[ProductBlinkBuildBasicID]
          self.blinkPlusBuildTrial = map[ProductBlinkPlusBuildBasicID]
          self.blinkPlusIntroOffer = map[ProductBlinkPlusID]
        }
      })
  }

  private lazy var _emailPredicate: NSPredicate = {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return NSPredicate(format:"SELF MATCHES %@", emailRegEx)
  }()

  private enum TrialDuration {
    case no
    case oneWeek
    case twoWeeks
    case oneMonth
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
