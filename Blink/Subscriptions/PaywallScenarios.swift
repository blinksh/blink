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
// You should have received a copy of the additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#if BLINK_PUBLISHING_OPTION_TESTAPPSTORE

import Foundation
import RevenueCat

// Purchase scenarios for manual paywall passes. Build with BLINK_PUBLISHING_OPTION_TESTAPPSTORE
// and pick one in `current`. Products and prices still come from the App Store sandbox; what
// the account holds and how sync, purchase and restore answer comes from the scenario.
struct PaywallScenario {
  static let current: PaywallScenario = .classicArrivesLater

  struct Holdings: OptionSet, CustomStringConvertible {
    let rawValue: Int

    static let classic   = Holdings(rawValue: 1 << 0)
    static let blinkPlus = Holdings(rawValue: 1 << 1)

    var description: String {
      var names: [String] = []
      if contains(.classic) { names.append("classic") }
      if contains(.blinkPlus) { names.append("blinkPlus") }
      return "[\(names.joined(separator: ", "))]"
    }
  }

  struct Step<Result> {
    let delay: TimeInterval
    let result: Result

    init(_ delay: TimeInterval, _ result: Result) {
      self.delay = delay
      self.result = result
    }
  }

  enum SyncResult {
    case nothingNew
    case finds(Holdings)
    case fails
  }

  enum PurchaseResult {
    // entitlementDelay lands the entitlement update after the purchase has returned.
    case newPurchase(entitlementDelay: TimeInterval = 0)
    // StoreKit's answer when the subscription is already active on the Apple ID.
    case existingTransaction
    case pending(approvedAfter: TimeInterval?)
    case alreadyPurchased
    case cancelled
    case fails
  }

  enum RestoreResult {
    case nothingFound
    case finds(Holdings)
    case fails
  }

  // What the app user holds at launch.
  var holdings: Holdings = []
  // A change that lands on its own, like a background refresh.
  var arrives: (after: TimeInterval, holdings: Holdings)? = nil
  // Answers are used in order; the last one repeats.
  var sync: [Step<SyncResult>] = [Step(1, .nothingNew)]
  var purchase: [Step<PurchaseResult>] = [Step(2, .newPurchase())]
  var restore: [Step<RestoreResult>] = [Step(1, .nothingFound)]
  // nil keeps the sandbox eligibility.
  var trialEligible: Bool? = nil
}

extension PaywallScenario {
  // MARK: Launch paywall

  // Classic shows up from a background refresh, as on a new device.
  static let classicArrivesLater = PaywallScenario(arrives: (after: 5, holdings: .classic))
  // Open a second window before it lands. The focused one reports, the other fades.
  static let blinkPlusArrivesLater = PaywallScenario(arrives: (after: 15, holdings: .blinkPlus))

  static let buyNew = PaywallScenario()
  static let buyNewEntitlementLate = PaywallScenario(purchase: [Step(2, .newPurchase(entitlementDelay: 3))])
  // BUY's sync finds an existing purchase, so no purchase is offered.
  static let buySyncFindsClassic = PaywallScenario(sync: [Step(1, .finds(.classic))])
  static let buySyncFindsBlinkPlus = PaywallScenario(sync: [Step(1, .finds(.blinkPlus))])
  // Offline: sync fails and the purchase goes ahead.
  static let buySyncFails = PaywallScenario(sync: [Step(3, .fails)])
  static let buyExistingTransaction = PaywallScenario(purchase: [Step(2, .existingTransaction)])
  // The follow-up sync links the purchase.
  static let buyAlreadyPurchased = PaywallScenario(sync: [Step(1, .nothingNew), Step(1, .finds(.blinkPlus))],
                                                   purchase: [Step(2, .alreadyPurchased)])
  static let buyPendingApproved = PaywallScenario(purchase: [Step(2, .pending(approvedAfter: 10))])
  static let buyCancelled = PaywallScenario(purchase: [Step(1, .cancelled)])
  static let buyFails = PaywallScenario(purchase: [Step(1, .fails)])

  static let restoreFindsClassic = PaywallScenario(restore: [Step(1, .finds(.classic))])
  static let restoreFindsBlinkPlus = PaywallScenario(restore: [Step(1, .finds(.blinkPlus))])
  static let restoreFindsNothing = PaywallScenario()
  static let restoreFails = PaywallScenario(restore: [Step(1, .fails)])

  static let trialOffer = PaywallScenario(trialEligible: true)
  static let noTrialOffer = PaywallScenario(trialEligible: false)

  // MARK: Settings, Get Blink+

  // RESTORE only finds Classic, so Blink+ is still not found. BUY makes a new purchase.
  static let classicUpgrade = PaywallScenario(holdings: .classic, restore: [Step(1, .finds(.classic))])
  static let classicUpgradeRestoresBlinkPlus = PaywallScenario(holdings: .classic, restore: [Step(1, .finds(.blinkPlus))])
}

struct PaywallScenarioError: LocalizedError {
  let errorDescription: String?
}

// Stands in for the RevenueCat entitlements source. Must be used from the main thread.
final class PaywallScenarioEntitlementsSource: EntitlementsSource {
  static let shared = PaywallScenarioEntitlementsSource(scenario: .current)

  weak var delegate: EntitlementsSourceDelegate?

  private let scenario: PaywallScenario
  private var holdings: PaywallScenario.Holdings
  private let log = Zuse.logger(.purchases, "Scenario")

  init(scenario: PaywallScenario) {
    self.scenario = scenario
    self.holdings = scenario.holdings
  }

  func startUpdates() {
    publish()
    if let arrives = scenario.arrives {
      add(arrives.holdings, after: arrives.after)
    }
  }

  func add(_ more: PaywallScenario.Holdings, after delay: TimeInterval = 0) {
    guard delay <= 0 else {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        self?.add(more)
      }
      return
    }
    holdings.formUnion(more)
    publish()
  }

  private func publish() {
    log.info("holdings \(holdings)")

    let blinkPlus = holdings.contains(.blinkPlus)
    let classic = holdings.contains(.classic)
    // Assumes Classic grants unlimited screen time but not early access.
    let unlimitedProductID = blinkPlus ? ProductBlinkPlusID : (classic ? ProductBlinkShellClassicID : nil)

    delegate?.didUpdateEntitlements(
      source: self,
      entitlements: [
        UnlimitedScreenTimeEntitlementID: Entitlement(id: UnlimitedScreenTimeEntitlementID,
                                                      active: unlimitedProductID != nil,
                                                      unlockProductID: unlimitedProductID,
                                                      period: unlimitedProductID != nil ? .Normal : .None),
        EarlyAccessFeaturesEntitlementID: Entitlement(id: EarlyAccessFeaturesEntitlementID,
                                                      active: blinkPlus,
                                                      unlockProductID: blinkPlus ? ProductBlinkPlusID : nil,
                                                      period: blinkPlus ? .Normal : .None),
        BuildEntitlementID: Entitlement.build
      ],
      activeSubscriptions: blinkPlus ? [ProductBlinkPlusID] : [],
      nonSubscriptionTransactions: classic ? [ProductBlinkShellClassicID] : []
    )
  }
}

@MainActor
final class PaywallScenarioStoreClient: StoreClient {
  private let source: PaywallScenarioEntitlementsSource
  private let scenario: PaywallScenario
  private var syncCount = 0
  private var purchaseCount = 0
  private var restoreCount = 0
  private let log = Zuse.logger(.purchases, "Scenario")

  init(source: PaywallScenarioEntitlementsSource, scenario: PaywallScenario = .current) {
    self.source = source
    self.scenario = scenario
  }

  func sync() async throws {
    let step = Self.next(scenario.sync, &syncCount)
    await Self.wait(step.delay)
    log.info("sync -> \(step.result)")

    switch step.result {
    case .nothingNew:
      break
    case .finds(let holdings):
      source.add(holdings)
    case .fails:
      throw PaywallScenarioError(errorDescription: "Simulated sync failure")
    }
  }

  func purchase(_ product: StoreProduct) async throws -> StorePurchase {
    let step = Self.next(scenario.purchase, &purchaseCount)
    await Self.wait(step.delay)
    log.info("purchase \(product.productIdentifier) -> \(step.result)")

    switch step.result {
    case .newPurchase(let entitlementDelay):
      source.add(.blinkPlus, after: entitlementDelay)
      return .completed(purchaseDate: Date())
    case .existingTransaction:
      source.add(.blinkPlus)
      return .completed(purchaseDate: Date().addingTimeInterval(-30 * 24 * 60 * 60))
    case .pending(let approvedAfter):
      if let approvedAfter {
        source.add(.blinkPlus, after: approvedAfter)
      }
      throw StoreClientError.pending
    case .alreadyPurchased:
      throw StoreClientError.alreadyPurchased
    case .cancelled:
      return .cancelled
    case .fails:
      throw PaywallScenarioError(errorDescription: "Simulated purchase failure")
    }
  }

  func restore() async throws {
    let step = Self.next(scenario.restore, &restoreCount)
    await Self.wait(step.delay)
    log.info("restore -> \(step.result)")

    switch step.result {
    case .nothingFound:
      break
    case .finds(let holdings):
      source.add(holdings)
    case .fails:
      throw PaywallScenarioError(errorDescription: "Simulated restore failure")
    }
  }

  private static func next<Result>(_ steps: [PaywallScenario.Step<Result>], _ count: inout Int) -> PaywallScenario.Step<Result> {
    defer { count += 1 }
    return steps[min(count, steps.count - 1)]
  }

  private static func wait(_ delay: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
  }
}

#endif
