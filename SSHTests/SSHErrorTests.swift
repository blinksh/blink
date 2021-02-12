//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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

import XCTest
import Combine
import Dispatch

@testable import SSH

class SSHErrorTests: XCTestCase {
  
  /**
   Tests that haven't been covered as there's no way to do it:
   - SSHError.noClient
   - SSHError.noChannel
   - SSHError.again
   - SSHError.notImplemented(_:)
   */
  
  var cancellableBag = Set<AnyCancellable>()
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  /**
   SSHError.authError(:) is thrown when trying to use a method to authenticate on a host that's not allowed.
   In this case is trying to use `AuthNone()` as an authetnication method for a host that doesn't accept it.
   */
  func testAuthError() throws {
    let config = SSHClientConfig(
      user: MockCredentials.wrongCredentials.user,
      port: MockCredentials.port,
      authMethods: []
    )
    
    let expectation = self.expectation(description: "Buffer Written")
    
    SSHClient.dial(MockCredentials.wrongCredentials.host, with: config)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Authentication should not have succeeded")
        case .failure(let error as SSHError):
          dump(error)
          if error == .authError(msg: "") {
            expectation.fulfill()
          } else {
            XCTFail("Unknown error")
          }
        case .failure(_):
          XCTFail("It should present an error of type SSHError.authError(msg:)")
        }
      }, receiveValue: { _ in
        XCTFail("Should not have received a connection")
      }).store(in: &cancellableBag)
    
    waitForExpectations(timeout: 5, handler: nil)
  }
  
  func testConnectionError() throws {
    
    let config = SSHClientConfig(
      user: MockCredentials.wrongHost.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.wrongHost.password)]
    )
    
    let expectation = self.expectation(description: "Buffer Written")
    
    SSHClient.dial(MockCredentials.wrongHost.host, with: config)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Authentication should not have succeeded")
        case .failure(let error as SSHError):
          dump(error)
          if error == .connError(msg: "") {
            expectation.fulfill()
          } else {
            XCTFail("Unknown error")
          }
        case .failure(_):
          XCTFail("It should present an error of type SSHError.connError(msg:)")
        }
      }, receiveValue: { _ in
        XCTFail("Should not have received a connection")
      }).store(in: &cancellableBag)
    
    waitForExpectations(timeout: 5, handler: nil)
  }
  
  /**
   Trying to authenticate against a host with either incorrect username or password credentials
   */
  func testAuthFailed() throws {
    
    let authMethods = [AuthPassword(with: MockCredentials.wrongCredentials.password)]
    
    let config = SSHClientConfig(
      user: MockCredentials.wrongCredentials.user,
      port: MockCredentials.port,
      authMethods: authMethods
    )
    
    let expectation = self.expectation(description: "Buffer Written")
    
    SSHClient.dial(MockCredentials.wrongCredentials.host, with: config)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Authentication should not have succeeded")
        case .failure(let error as SSHError):
          
          if error == .authFailed(methods: authMethods) {
            expectation.fulfill()
          } else {
            XCTFail("Unknown error")
          }
        case .failure(_):
          XCTFail("It should present an error of type SSHError.authFailed(methods:)")
          
        }
      }, receiveValue: { _ in
        XCTFail("Should not have received a connection")
      }).store(in: &cancellableBag)
    
    waitForExpectations(timeout: 10, handler: nil)
  }
  
  /**
   Given a wrong/fake IP it should fail as the host couldn't be translated to a usable IP.
   
   Uses the `SSHClient.urlToIpHostResolution(_:)`
   */
  func testCouldntResolveHostAddress() throws {
    let config = SSHClientConfig(
      user: MockCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.password)]
    )
    
    let expectation = self.expectation(description: "Buffer Written")
    
    SSHClient.dial(MockCredentials.incorrectIpHost, with: config)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error as SSHError):
          /// The given IP address couldn't be resolved into an IP address
          expectation.fulfill()
          
        case .failure(let genericError):
          XCTFail("Shouldn't have received an error that's not of type SSHError \(genericError.localizedDescription)")
        }
      }, receiveValue: { _ in
        XCTFail("Shouldn't have received a connection")
      }).store(in: &cancellableBag)
    
    waitForExpectations(timeout: 5, handler: nil)
  }
  
  override func tearDown() {
    cancellableBag.removeAll()
  }
}
