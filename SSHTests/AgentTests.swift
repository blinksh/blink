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
    let key = try SSHKey(fromFileBlob: Credentials.privateKey.data(using: .utf8)!)
    agent.loadKey(key, aka: "testKey")

    let config = SSHClientConfig(user: Credentials.publicKeyAuthentication.user,
                                 port: Credentials.port,
                                 authMethods: [AuthAgent(agent)],
                                 agent: agent)

    var completion: Any? = nil

    let connection = SSHClient.dial(Credentials.publicKeyAuthentication.host, with: config)
      .lastOutput(
      test: self,
        receiveCompletion: {
          completion = $0
        })

    assertCompletionFinished(completion)
    XCTAssertNotNil(connection)
  }

  // Curve keys have another headers during construction. We test here that we are still doing it properly.
  func testAgentAuthenticationWithCurveKey() throws {
    let agent = SSHAgent()
    let key = try SSHKey(fromFileBlob: Credentials.curvePrivateKey.data(using: .utf8)!)
    agent.loadKey(key, aka: "test")

    let config = SSHClientConfig(user: Credentials.publicKeyAuthentication.user,
                                 port: Credentials.port,
                                 authMethods: [AuthAgent(agent)],
                                 agent: agent)

    var completion: Any? = nil

    let connection = SSHClient.dial(Credentials.publicKeyAuthentication.host, with: config)
      .lastOutput(
      test: self,
        receiveCompletion: {
          completion = $0
        })

    assertCompletionFinished(completion)
    XCTAssertNotNil(connection)
  }
  
  // https://goteleport.com/blog/how-to-ssh-properly/
  func testAgentAuthenticationWithCertificate() throws {
    let agent = SSHAgent()
    let bundle = Bundle(for: type(of: self))
    let privPath = bundle.path(forResource: "user_key", ofType: nil)
    let pubPath  = bundle.path(forResource: "user_key-cert", ofType: "pub")
    let key = try SSHKey(fromFile: privPath!, withPublicFileCert: pubPath!)
    
    agent.loadKey(key, aka: "certTest")
    
    let config = SSHClientConfig(user: Credentials.publicKeyAuthentication.user,
                                 port: Credentials.port,
                                 authMethods: [AuthAgent(agent)],
                                 agent: agent)

    var completion: Any? = nil

    let connection = SSHClient.dial(Credentials.publicKeyAuthentication.host, with: config)
      .lastOutput(
      test: self,
        receiveCompletion: {
          completion = $0
        })

    assertCompletionFinished(completion)
    XCTAssertNotNil(connection)
  }
  
  func testAgentForwarding() throws {
    // Do a second session to itself by using the forwarded agent.
    let cmd = "ssh -o StrictHostKeyChecking=no localhost -- echo hola"
    let agent = SSHAgent()
    let key = try SSHKey(fromFileBlob: Credentials.privateKey.data(using: .utf8)!)
    agent.loadKey(key, aka: "testKey")

    let config = SSHClientConfig(user: Credentials.publicKeyAuthentication.user,
                                 port: Credentials.port,
                                 authMethods: [AuthAgent(agent)],
                                 agent: agent)

    var completion: Any? = nil

    let read = SSHClient.dial(Credentials.publicKeyAuthentication.host, with: config)
      .flatMap { $0.requestExec(command: cmd, withAgentForwarding: true) }
      .flatMap { $0.read(max: SSIZE_MAX) }
      .exactOneOutput(
      test: self,
        timeout: 15,
        receiveCompletion: {
          completion = $0
        })

    assertCompletionFinished(completion)
    guard let data: DispatchData = read else {
      XCTFail()
      return
    }
    let output = String(bytes: data, encoding: .utf8)
    XCTAssertTrue(output == "hola\n")
  }
}

