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


import Foundation
import SwiftUI

@MainActor
class BuildAccountModel: ObservableObject {
  
  @Published var showPlanInfo: Bool = false
  // MARK: Signup
  @Published var signupInProgress: Bool = false
  @Published var alertErrorMessage: String = ""
  @Published var email: String = "" {
    didSet {
      emailIsValid = !email.isEmpty && _emailPredicate.evaluate(with: email)
    }
  }
  
  @Published var emailIsValid: Bool = false
  @Published var buildRegion: BuildRegion = BuildRegion.usEast1
  
  // MARK: Account Info
 
  @Published var accountInfoLoadingInProgress: Bool = false
  @Published var showTour: Bool = false
  
//  @Published var flow: Int = 0
  
  @Published var hasBuildToken: Bool = false
  @Published var usageBalance: BuildUsageBalance? = nil
//  @Published var isStagingEnv: Bool = false {
//    didSet {
//      let isOn = isStagingEnv
//      DispatchQueue(label: "file operation").async {
//        let url = BlinkPaths.blinkBuildStagingMarkURL()!
//        if isOn {
//          try? Data().write(to: url)
//        } else {
//          try? FileManager.default.removeItem(at: url)
//        }
//      }
//
//    }
//  }
  
//  init() {
//    if FeatureFlags.blinkBuildStaging {
//      self.isStagingEnv = FileManager.default.fileExists(atPath: BlinkPaths.blinkBuildStagingMarkURL()!.path)
//    }
//  }
  
  private lazy var _emailPredicate: NSPredicate = {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return NSPredicate(format:"SELF MATCHES %@", emailRegEx)
  }()
  
  func checkBuildToken(animated: Bool, showTour: Bool = false) {
    let value = FileManager.default.fileExists(atPath: BlinkPaths.blinkBuildTokenURL().path)
    guard self.hasBuildToken != value else {
      return
    }
    if animated {
      withAnimation {
        self.hasBuildToken = value
        if value {
          self.showTour = showTour
        }
      }
    } else {
      self.hasBuildToken = value
    }
  }
  
  func signup() async {
    guard emailIsValid else {
      self.alertErrorMessage =  self.email.isEmpty ? "Email is Required" :  "Valid email is Required"
      return
    }
    
    withAnimation {
      self.signupInProgress = true
    }
    
    defer {
      self.signupInProgress = false
    }
    
    do {
      try await BuildAPI.signup(email: self.email, region: self.buildRegion)
      self.checkBuildToken(animated: true, showTour: true)
    } catch {
      self.alertErrorMessage = error.localizedDescription
    }
  }
  
  public func singin() async throws {
    try await BuildAPI.signin()
    self.checkBuildToken(animated: false)
  }
  
  public func trySignIn() async {
    do {
      // we have subscription. Lets try to signin first
      try await BuildAPI.trySignin()
      self.checkBuildToken(animated: true)
    } catch {
      print("failed to sign in")
    }
  }
  
  public func fetchAccountInfo() async {
    withAnimation {
      self.accountInfoLoadingInProgress = true
    }
    defer {
      withAnimation {
        self.accountInfoLoadingInProgress = false
      }
    }
    
    do {
      let info = try await BuildAPI.accountInfo()
      withAnimation {
        self.email = info.email
        if let region = BuildRegion(rawValue: info.region) {
          self.buildRegion = region
        }
      }
    } catch {
      self.alertErrorMessage = error.localizedDescription
    }
  }
  
  public func fetchUsageBalance() async {
    do {
      self.usageBalance = try await BuildAPI.accountCurrentUsageBalance()
    } catch {
      self.alertErrorMessage = error.localizedDescription
    }
  }
  
  public func requestAccountDelete() async {
    do {
      try await BuildAPI.requestAccountDelete()
      try? FileManager.default.removeItem(atPath: BlinkPaths.blinkBuildTokenURL().path)
      self.hasBuildToken = false
    } catch {
      let error = error.localizedDescription
      self.alertErrorMessage = error
    }
  }
  
  func openTermsOfService() {
    blink_openurl(URL(string: "https://blink.sh/build-tos")!)
  }
  
  static let shared = BuildAccountModel()

}
