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

import Combine
import XCTest

import SSH

class SEKeyTests: XCTestCase {
  let testKeyTag = "testkey"
  var key: SEKey!
  
  override func setUpWithError() throws {
    #if targetEnvironment(simulator)
      throw XCTSkip("No Secure Enclave on simulator")
    #endif
    // Put setup code here. This method is called before the invocation of each test method in the class.
    try? SEKey.delete(tag: testKeyTag)
    key = try SEKey.create(tagged: testKeyTag)
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    try SEKey.delete(tag: testKeyTag)
  }
  
  func testSEKey() throws {
    guard let blob = "TestString".data(using: .utf8) else { XCTFail(); return }
    let sig = try key.signDER(blob)
    
    XCTAssertTrue(try (key.publicKey as! SEPublicKey).verifyDER(signature: sig, of: blob))
  }
  
  func testSEPubKey() throws {
    continueAfterFailure = false
    
    guard let pubAuthKey = key.publicKey.authorizedKey(withComment: nil) else {
      XCTFail("No authorizedkey representation for SEKey.")
      return
    }
    let components = pubAuthKey.components(separatedBy: " ")
    XCTAssertTrue(components.count == 2)

    guard let blob = Data(base64Encoded: components[1]) else {
      XCTFail("Could not decode key blob")
      return
    }
    
    // The key should be able to go back to OpenSSH
    let key = try SSHKey(fromPublicBlob: blob)
    XCTAssertNotNil(key)
  }
  
  func testAgentSEKey() throws {
    continueAfterFailure = false
    var cancellableBag: Set<AnyCancellable> = []
    
    // First install the SEKey on authorized keys for access.
    guard let authorizedKey = key.publicKey.authorizedKey(withComment: "sekey") else {
      XCTFail("No authorizedKey representation for SEKey.")
      return
    }
    var connection: SSHClient?
    
    let expectKeyInstalled = self.expectation(description: "Key installed in remote")
    let cmd = "echo \"\(authorizedKey)\" >> ~/.ssh/authorized_keys"
    let configPass = SSHClientConfig(user: "regular",
                                     port: "2222",
                                     authMethods: [AuthPassword(with: "regular")])
    
    SSHClient.dial("localhost", with: configPass)
      .flatMap { conn -> AnyPublisher<SSH.Stream, Error> in
        connection = conn
        return conn.requestExec(command: cmd)
      }.flatMap { $0.read(max: 1024) }
      .assertNoFailure()
      .sink { buf in
        expectKeyInstalled.fulfill()
      }.store(in: &cancellableBag)
    
    wait(for: [expectKeyInstalled], timeout: 10)
    XCTAssertNotNil(connection)
    
    // Now connect with the installed SEKey
    let expectSEConn = self.expectation(description: "Expect SE Connected")
    let agent = SSHAgent()
    agent.loadKey(key, aka: "SEKey")
    let configKey = SSHClientConfig(user: "regular",
                                    port: "2222",
                                    authMethods: [AuthAgent(agent)],
                                    agent: agent)
    SSHClient.dial("localhost", with: configKey)
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
        expectSEConn.fulfill()
      }).store(in: &cancellableBag)
    
    wait(for: [expectSEConn], timeout: 1000)
    XCTAssertNotNil(connection)
  }
}
