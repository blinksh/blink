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
import CryptoKit

@testable import SSH

extension Digest {
  var bytes: [UInt8] { Array(makeIterator()) }
  var data: Data { Data(bytes) }

  var hexStr: String {
    bytes.map { String(format: "%02X", $0) }.joined()
  }
}

// Test different PKCS types? Just to make sure we are using the
// right functions the right way?
class AgentTests: XCTestCase {

  // Test the Signatures happen properly with RSA Keys, as those may include special algorithms
  func testAgentAuthenticationWithRSAKey() throws {
    let agent = SSHAgent()
    //try agent.loadKey(fromBlob: MockCredentials.notCopiedPrivateKey.data(using: .utf8)!)
    let key = try SSHKey(fromFileBlob: Credentials.privateKey.data(using: .utf8)!)
    try agent.loadKey(key, aka: "testKey")

    let config = SSHClientConfig(user: "carloscabanero", authMethods: [AuthAgent(agent)], agent: agent, loggingVerbosity: .debug)

    let expectation = self.expectation(description: "SSH connected")

    var connection: SSHClient?

    let c = SSHClient.dial("localhost", with: config)
      .sink(receiveCompletion: { completion in
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
      }, receiveValue: { conn in
        connection = conn
        expectation.fulfill()
      })

    waitForExpectations(timeout: 3, handler: nil)
    XCTAssertNotNil(connection)
  }

  // Curve keys have another headers during construction. We test here that we are still doing it properly.
  func testAgentAuthenticationWithCurveKey() throws {
    let agent = SSHAgent()
    let key = try SSHKey(fromFileBlob: Credentials.curvePrivateKey.data(using: .utf8)!)
    try agent.loadKey(key, aka: "test")

    let config = SSHClientConfig(user: "carloscabanero", authMethods: [AuthAgent(agent)], agent: agent, loggingVerbosity: .debug)

    let expectation = self.expectation(description: "SSH connected")

    var connection: SSHClient?
    let c = SSHClient.dial("localhost", with: config)
      .sink(receiveCompletion: { completion in
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
      }, receiveValue: { conn in
        connection = conn
        expectation.fulfill()
      })

    waitForExpectations(timeout: 3, handler: nil)
    XCTAssertNotNil(connection)
  }

  func testAgentAuthenticationWithCertificate() throws {
    let agent = SSHAgent()
    let bundle = Bundle(for: type(of: self))
    let privPath = bundle.path(forResource: "user_key", ofType: nil)
    let pubPath  = bundle.path(forResource: "user_key-cert", ofType: "pub")
    let key = try SSHKey(fromFile: privPath!, withPublicFileCert: pubPath!)
    
    try agent.loadKey(key, aka: "keyTest")
    
    let config = SSHClientConfig(user: "carloscabanero", authMethods: [AuthAgent(agent)], agent: agent, loggingVerbosity: .debug)
    
    let expectation = self.expectation(description: "SSH connected")

    var connection: SSHClient?
    let c = SSHClient.dial("localhost", with: config)
      .sink(receiveCompletion: { completion in
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
            }, receiveValue: { conn in
                 connection = conn
                 expectation.fulfill()
               })

    waitForExpectations(timeout: 3, handler: nil)
    XCTAssertNotNil(connection)
  }
}

// Encoding PKCS12. PFX is rarely used, and we can say we do not accept it.
// PKCS8 or PKCS1 version. When we generate and export we should use PKCS8, but
// otherwise we can just store the blob as is.
