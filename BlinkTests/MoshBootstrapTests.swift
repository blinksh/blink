//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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

@testable import Blink

final class MoshBootstrapTests: XCTestCase {
  var cancellableBag: Set<AnyCancellable> = []
  
  func testMoshBootstrap2() throws {
    print("connecting...")
    
    //let client = try await SSHClient.dial("localhost", with: .testConfig).values.first()!
    let expectConn = self.expectation(description: "Connection established")
    
    var connection: SSHClient!
    SSHClient.dial("localhost", with: .testConfig)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { conn in
          connection = conn
          expectConn.fulfill()
        }).store(in: &cancellableBag)

    wait(for: [expectConn], timeout: 5)

    print("connected")
    
    let expectBootstrap = self.expectation(description: "Mosh bootstrapped")

    MoshBootstrap(client: connection)
      .start()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { moshServerPath in
          print("Mosh server path at: \(moshServerPath)")
        }
      ).store(in: &cancellableBag)
    
    wait(for: [expectBootstrap], timeout: 30)
    
  }
}

extension SSHClientConfig {
  static let testConfig = SSHClientConfig(
    user: "carloscabanero",
    port: "22",
    authMethods: [AuthPassword(with: "asdfzxcv")],
    loggingVerbosity: .debug
  )
}
