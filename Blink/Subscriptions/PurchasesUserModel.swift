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
import Network
import SwiftUI
import UIKit

// Does things with the store and tells what happened: products, purchases, restores, and the
// messages about them, shared by any paywall.
@MainActor
class PurchasesUserModel: ObservableObject {
  // MARK: products
  // @Published var blinkShellPlusProduct: StoreProduct? = nil
  @Published var buildBasicProduct: StoreProduct? = nil
  // @Published var classicProduct: StoreProduct? = nil
  @Published var blinkPlusBuildBasicProduct: StoreProduct? = nil
  @Published var blinkPlusProduct: StoreProduct? = nil

  @Published var blinkBuildTrial: IntroEligibility? = nil
  @Published var blinkPlusBuildTrial: IntroEligibility? = nil
  @Published var blinkPlusIntroOffer: IntroEligibility? = nil

  // MARK: Progress indicators
  @Published var purchaseInProgress: Bool = false
  @Published var restoreInProgress: Bool = false

  @Published var buildBasicTrialEligibility: IntroEligibility? = nil

  @Published var alertErrorMessage: String = ""
  // Set while products cannot be loaded
  @Published var productsUnavailableMessage: String? = nil

  var isBuildBasicTrialEligible: Bool {
    self.buildBasicTrialEligibility?.status == .eligible
  }

  private let store: StoreClient
  private let pathMonitor = NWPathMonitor()

  private init() {
#if BLINK_PUBLISHING_OPTION_TESTAPPSTORE
    store = PaywallScenarioStoreClient(source: .shared)
#else
    store = RevenueCatStoreClient()
#endif

    // Products load whenever there is a connection and they are still missing. The first
    // update arrives right after start, so this is also the initial load.
    pathMonitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor in
        guard let self else {
          return
        }
        if online {
          self.fetchProducts()
          self.fetchTrialEligibility()
        } else if self.blinkPlusProduct == nil {
          self.productsUnavailableMessage = "No internet connection. Prices will load once you are back online."
        }
      }
    }
    pathMonitor.start(queue: .main)
  }

  static let shared = PurchasesUserModel()

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

  // Links purchases made with this Apple ID to the app user. Sync instead of restore, as
  // RevenueCat warns a programmatic restore may prompt for sign-in.
  func link() async {
    try? await store.sync()
  }

  func purchaseBlinkPlus(trialReminder: Bool) async -> PurchaseResult {
    guard let product = blinkPlusProduct else {
      self.alertErrorMessage = "No valid products selected"
      return .failed
    }
    return await purchase(product, trialReminder: trialReminder)
  }

  // Trial reminders are set up before the purchase and kept only if it goes through.
  func purchase(_ product: StoreProduct, trialReminder: Bool) async -> PurchaseResult {
    if trialReminder {
      guard await _setupTrialProgressNotification(TrialProgressNotification.TwoWeeks) else {
        return .failed
      }
    }

    var keepTrialReminder = false
    defer {
      if trialReminder && !keepTrialReminder {
        TrialProgressNotification.cancel()
      }
    }

    let purchaseStartedAt = Date()
    do {
      guard case .completed(let purchaseDate) = try await store.purchase(product) else {
        return .cancelled
      }

      // StoreKit answers an already active subscription with its existing transaction.
      // The margin absorbs device clock skew.
      if let purchaseDate, purchaseDate < purchaseStartedAt.addingTimeInterval(-5 * 60) {
        return .alreadyOwned
      }

      keepTrialReminder = true
      return .purchased
    } catch StoreClientError.pending {
      keepTrialReminder = true
      self.alertErrorMessage = "Your purchase is pending approval. Blink will unlock as soon as it is approved."
      return .pending
    } catch StoreClientError.alreadyPurchased {
      try? await store.sync()
      return .alreadyOwned
    } catch {
      self.alertErrorMessage = "Purchase cannot be completed. Please try again. Details: \(error.localizedDescription)"
      return .failed
    }
  }

  // Returns false if the restore failed, after reporting it.
  @discardableResult
  func restore() async -> Bool {
    self.restoreInProgress = true

    defer {
      self.refreshTokens()
      self.restoreInProgress = false
    }

    do {
      try await store.restore()
    } catch {
      self.alertErrorMessage = error.localizedDescription
      return false
    }

    if EntitlementsManager.shared.build.active {
      await BuildAccountModel.shared.trySignIn()
    }
    return true
  }

  func reportNothingFound() {
    self.alertErrorMessage = "Could not find an active subscription. Please contact us if you are having trouble."
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
#if BLINK_PUBLISHING_OPTION_TESTAPPSTORE
    if let eligible = PaywallScenario.current.trialEligible {
      return eligible
    }
#endif
    return blinkPlusIntroOffer?.status == IntroEligibilityStatus.eligible
  }

  func getUserID() -> String { Purchases.shared.appUserID }

  // MARK: Trial reminders

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

  // MARK: - Friendly helpers

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

  func restoreBlinkBuildEntitlements(alertIfNone: Bool) async -> Bool {
    await restore()
    
    if EntitlementsManager.shared.build.active {
      return true
    } else {
      if alertIfNone {
        self.alertErrorMessage = "Could not find Blink Build entitlements in your subscription."
      }
      return false
    }
  }
  
  // func formattedPlusPriceWithPeriod() -> String? {
  //   blinkShellPlusProduct?.formattedPriceWithPeriod()
  // }

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
    guard blinkPlusProduct == nil else {
      return
    }
    productsUnavailableMessage = nil
    Purchases.shared.getProducts([
      // ProductBlinkShellClassicID,
      // ProductBlinkShellPlusID,
      ProductBlinkBuildBasicID,
      ProductBlinkPlusBuildBasicID,
      ProductBlinkPlusID
    ]) { products in
      DispatchQueue.main.async {
        for product in products {
          let productID = product.productIdentifier

          // if productID == ProductBlinkShellPlusID {
          //   self.blinkShellPlusProduct = product
          // } else if productID == ProductBlinkShellClassicID {
          //   self.classicProduct = product
          // } else
          if productID == ProductBlinkBuildBasicID {
            self.buildBasicProduct = product
          } else if productID == ProductBlinkPlusBuildBasicID {
            self.blinkPlusBuildBasicProduct = product
          } else if productID == ProductBlinkPlusID {
            self.blinkPlusProduct = product
          }
        }
        if self.blinkPlusProduct == nil {
          self.productsUnavailableMessage = "Could not reach the App Store. Prices will load once the connection is back."
        }
      }
    }
  }

  private func fetchTrialEligibility() {
    // Unknown is what comes back without a connection.
    guard blinkPlusIntroOffer == nil || blinkPlusIntroOffer?.status == .unknown else {
      return
    }
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
}

// MARK: Open links
extension PurchasesUserModel {
  func openPrivacyAndPolicy() {
    blink_openurl(URL(string: "https://blink.sh/pp")!)
  }

  func openTermsOfUse() {
    blink_openurl(URL(string: "https://blink.sh/blink-gpl")!)
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


// Failures and pending purchases are reported to the user by the time this is returned.
enum PurchaseResult {
  case purchased
  // The product was already owned by this Apple ID. Its entitlements arrive as an update.
  case alreadyOwned
  case cancelled
  // Waiting for approval, like Ask to Buy. Its entitlements arrive as an update.
  case pending
  case failed
}

enum StorePurchase {
  case completed(purchaseDate: Date?)
  case cancelled
}

enum StoreClientError: Error {
  case pending
  case alreadyPurchased
}

// The store calls behind the paywall. Each call has brought the entitlements up to date by
// the time it returns.
@MainActor
protocol StoreClient {
  func sync() async throws
  func purchase(_ product: StoreProduct) async throws -> StorePurchase
  func restore() async throws
}

@MainActor
struct RevenueCatStoreClient: StoreClient {
  func sync() async throws {
    _apply(try await Purchases.shared.syncPurchases())
  }

  func purchase(_ product: StoreProduct) async throws -> StorePurchase {
    do {
      let result = try await Purchases.shared.purchase(product: product)
      if result.userCancelled {
        return .cancelled
      }
      _apply(result.customerInfo)
      return .completed(purchaseDate: result.transaction?.purchaseDate)
    } catch {
      switch error as? RevenueCat.ErrorCode {
      case .paymentPendingError?:
        throw StoreClientError.pending
      case .productAlreadyPurchasedError?:
        throw StoreClientError.alreadyPurchased
      default:
        throw error
      }
    }
  }

  func restore() async throws {
    _apply(try await Purchases.shared.restorePurchases())
  }

  // RevenueCat dispatches delegate updates asynchronously. Applying the CustomerInfo a call
  // returns lets a check right after that call see it, e.g. before offering a purchase.
  private func _apply(_ info: CustomerInfo) {
    Purchases.shared.delegate?.purchases?(Purchases.shared, receivedUpdated: info)
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
