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

func __assertCompletionFailure(_ completion: Any?, withError error: SSHError, file: StaticString = #filePath, line: UInt = #line) {
  guard
    let c = completion as? Subscribers.Completion<Error>,
    let err = c.error as? SSHError,
    err == error
  else {
    XCTFail("Should completed with .faulure(\(error). Got: " + String(describing: completion), file: file, line: line)
    return
  }
}

class SSHErrorTests: XCTestCase {
  
  /**
   Tests that haven't been covered as there's no way to do it:
   - SSHError.noClient
   - SSHError.noChannel
   - SSHError.again
   - SSHError.notImplemented(_:)
   */
  
  /**
   SSHError.authError(:) is thrown when trying to use a method to authenticate on a host that's not allowed.
   In this case is trying to use `AuthNone()` as an authetnication method for a host that doesn't accept it.
   */
  func testAuthError() {
    let config = SSHClientConfig(
      user: MockCredentials.wrongCredentials.user,
      port: MockCredentials.port,
      authMethods: []
    )
    
    var completion: Any? = nil

    SSHClient
      .dial(MockCredentials.wrongCredentials.host, with: config)
      .sink(
        test: self,
        receiveCompletion: {
          completion = $0
        },
        receiveValue: { _ in
          XCTFail("Should not have received a connection")
        }
      )
    
    __assertCompletionFailure(completion, withError: .authError(msg: ""))
  }
  
  func testConnectionError() {
    let config = SSHClientConfig(
      user: MockCredentials.wrongHost.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.wrongHost.password)]
    )

    var completion: Any? = nil

    SSHClient.dial(MockCredentials.wrongHost.host, with: config)
      .sink(
        test: self,
        receiveCompletion: {
          completion = $0
        }, receiveValue: { _ in
          XCTFail("Should not have received a connection")
        }
      )
    
    __assertCompletionFailure(completion, withError: .connError(msg: ""))
  }
  
  /**
   Trying to authenticate against a host with either incorrect username or password credentials
   */
  func testAuthFailed() {
    let authMethods = [AuthPassword(with: MockCredentials.wrongCredentials.password)]
    
    let config = SSHClientConfig(
      user: MockCredentials.wrongCredentials.user,
      port: MockCredentials.port,
      authMethods: authMethods
    )
    
    var completion: Any? = nil

    SSHClient.dial(MockCredentials.wrongCredentials.host, with: config)
      .sink(
        test: self,
        receiveCompletion: {
          completion = $0
      }, receiveValue: { _ in
        XCTFail("Should not have received a connection")
      })
    __assertCompletionFailure(completion, withError: .authFailed(methods: authMethods))
  }
  
  /**
   Given a wrong/fake IP it should fail as the host couldn't be translated to a usable IP.
   */
  func testCouldntResolveHostAddress() throws {
    let config = SSHClientConfig(
      user: MockCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.password)]
    )
    
    var completion: Any? = nil
    
    SSHClient.dial(MockCredentials.incorrectIpHost, with: config)
      .sink(
        test: self,
        receiveCompletion: {
          completion = $0
        },
        receiveValue: { _ in
          XCTFail("Shouldn't have received a connection")
        })
    
    __assertCompletionFailure(completion, withError: .connError(msg: "Socket error: No such file or directory"))
  }
}
