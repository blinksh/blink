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

struct Credentials {
  let user: String
  let password: String
  let host: String
}

class AuthTests: XCTestCase {
  
  override class func setUp() {
    SSHInit()
  }
    
  func testPasswordAuthenticationWithCallback() throws {
    let requestAnswers: SSHClientConfig.RequestVerifyHostCallback = { (prompt) in
      return Just(InteractiveResponse.affirmative).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)],
      verifyHostCallback: requestAnswers
    )
    
    let connection = SSHClient
      .dial(MockCredentials.passwordCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  func testPasswordAuthentication() throws {
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)]
    )
    
    let connection = SSHClient
      .dial(MockCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  /**
   Feed the wrong private key to the test and then continue as normal to test partial authentication.
   */
  func testPartialAuthenticationFailingFirst() throws {
    let config = SSHClientConfig(
      user: MockCredentials.partialAuthenticationCredentials.user,
      port: MockCredentials.port,
      authMethods: [
        AuthPublicKey(privateKey: MockCredentials.notCopiedPrivateKey),
        AuthPassword(with: MockCredentials.partialAuthenticationCredentials.password),
        AuthPublicKey(privateKey: MockCredentials.privateKey)
      ])

    let connection = SSHClient
      .dial(MockCredentials.partialAuthenticationCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  /**
   Only providing a method of the two needed to authenticate. Should fail as it also need password authentication to be provided.
   */
  func testFailingPartialAuthentication() throws {
    let config = SSHClientConfig(
      user: MockCredentials.partialAuthenticationCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPublicKey(privateKey: MockCredentials.notCopiedPrivateKey)]
    )
    
    let connection = SSHClient
      .dial(MockCredentials.partialAuthenticationCredentials.host, with: config)
      .lastOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            XCTFail("Unexpected completion. Should failed")
          case .failure(let error):
            if let error = error as? SSHError {
              if case SSHError.authFailed = error {
                break
              }
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNil(connection)
  }
  
  /**
   
   */
  func testPartialAuthentication() throws {
    let config = SSHClientConfig(
      user: MockCredentials.partialAuthenticationCredentials.user,
      port: MockCredentials.port,
      authMethods: [
        AuthPublicKey(privateKey: MockCredentials.privateKey),
        AuthPassword(with: MockCredentials.partialAuthenticationCredentials.password)
      ]
    )
    
    let connection = SSHClient
      .dial(MockCredentials.partialAuthenticationCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  // MARK: Wrong credentials
  // This test should fail before the timeout expecation is consumed
  func testFailWithWrongCredentials() throws {
    let config = SSHClientConfig(
      user: MockCredentials.wrongCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.wrongCredentials.password)]
    )
    
    let expectation = self.expectation(description: "SSH config")
    
    SSHClient
      .dial(MockCredentials.wrongCredentials.host, with: config)
      .sink(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            XCTFail("Connection succeded for wrong credentials")
          case .failure(let error):
            if let error = error as? SSHError {
              // TODO Assert error is an Auth error
              print(error.description)
              
              // Connection failed, which is what we wanted to test.
              expectation.fulfill()
              break
            }
            XCTFail("Unknown error during connection")
          }
        }, receiveValue: { _ in
          XCTFail("Should not have received a connection")
        }
      )
    
    wait(for: [expectation], timeout: 10)
  }
  
  // MARK: No authentication methods provided
  
  /**
   Don't provide any authentication methods. Should succeed with a host that has none auth method
   */
  func testEmptyAuthMethods() throws {
    let config = SSHClientConfig(
      user: MockCredentials.noneCredentials.user,
      port: MockCredentials.port,
      authMethods: []
    )
    
    let connection = SSHClient
      .dial(MockCredentials.noneCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  func testNoneAuthentication() throws {
    let config = SSHClientConfig(
      user: MockCredentials.noneCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthNone()]
    )
    
    let connection = SSHClient
      .dial(MockCredentials.noneCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  /**
   Test first a failing method then a method that succeeds.
   */
  func testFirstFailingThenSucceeding() throws {
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [
        AuthPassword(with: MockCredentials.wrongCredentials.password),
        AuthPassword(with: MockCredentials.passwordCredentials.password)
      ]
    )
    
    let connection = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .lastOutput(
        test: self,
        timeout: 10,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  // MARK: Public Key Authentication
  
  /**
   Should fail when importing a private key `wrongPrivateKey` that's not correctly formatted.
   */
  func testImportingIncorrectPrivateKey() throws {
    
    let config = SSHClientConfig(
      user: MockCredentials.publicKeyAuthentication.user,
      port: MockCredentials.port,
      authMethods: [AuthPublicKey(privateKey: MockCredentials.wrongPrivateKey)]
    )
    
    let expectation = self.expectation(description: "SSH config")
    
    SSHClient
      .dial(MockCredentials.publicKeyAuthentication.host, with: config)
      .sink(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              if case SSHError.authError = error {
                expectation.fulfill()
                break
              }
            }
            
            XCTFail("Unknown error")
          }
        }
      )
    
    wait(for: [expectation], timeout: 10)
  }
  
  func testPubKeyAuthentication() throws {
    
    let config = SSHClientConfig(
      user: MockCredentials.publicKeyAuthentication.user,
      port: MockCredentials.port,
      authMethods: [AuthPublicKey(privateKey: MockCredentials.privateKey)]
    )
    
    let connection = SSHClient.dial(MockCredentials.publicKeyAuthentication.host, with: config)
      .lastOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    XCTAssertNotNil(connection)
  }
  
  // MARK: Interactive Keyboard Authentication
  func testInteractiveKeyboardAuth() throws {
    var retry = 0
    
    let requestAnswers: AuthKeyboardInteractive.RequestAnswersCb = { prompt in
      dump(prompt)
      
      var answers: [String] = []
      
      if prompt.userPrompts.count > 0 {
        // Fail on first retry
        if retry > 0 {
          answers = [MockCredentials.interactiveCredentials.password]
        } else {
          retry += 1
          answers = []
        }
      } else {
        answers = []
      }
      
      return Just(answers).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    let config = SSHClientConfig(
      user: MockCredentials.interactiveCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthKeyboardInteractive(requestAnswers: requestAnswers)]
    )
    
    let connection = SSHClient
      .dial(MockCredentials.interactiveCredentials.host, with: config)
      .exactOneOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    waitForExpectations(timeout: 5, handler: nil)
    
    XCTAssertNotNil(connection)
  }
}
