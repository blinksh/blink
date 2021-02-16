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
import BlinkFiles
import Combine
import Dispatch

@testable import SSH


class SCPTests: XCTestCase {
  
  func testSCPInit() throws {
    let scp = SSHClient
      .dialWithTestConfig()
      .flatMap() { c -> AnyPublisher<SCPClient, Error> in
        print("Received connection")
        return SCPClient.execute(using: c, as: .Sink, root: "/tmp")
      }
      .assertNoFailure()
      .lastOutput(test: self)
    
    dump(scp)
    XCTAssertNotNil(scp)
  }
  
  func testSCPFileCopyFrom() throws {    
    let expectation = self.expectation(description: "sftp")
    
    var connection: SSHClient?
    var sftp: SFTPClient?
    var scp: SCPClient?
    var totalWritten: UInt64 = 0
    
    let c1 = SSHClient.dialWithTestConfig()
      .flatMap() { conn -> AnyPublisher<SCPClient, Error> in
        connection = conn
        return SCPClient.execute(using: conn, as: .Sink, root: "/tmp")
      }.assertNoFailure()
      .sink { client in
        scp = client
        expectation.fulfill()
      }
    
    wait(for: [expectation], timeout: 15)
    
    let expectation2 = self.expectation(description: "scp")
    let c2 = connection?.requestSFTP().flatMap { client -> AnyPublisher<Translator, Error> in
      sftp = client
      return sftp!.walkTo("Xcode_12.0.1.xip")
    }.flatMap { sourceFile in
      return scp!.copy(from: [sourceFile])
    }
    .sink(receiveCompletion: { completion in
      switch completion {
      case .finished:
        expectation2.fulfill()
      case .failure(let error):
        // Problem here is we can have both SFTP and SSHError
        XCTFail("Crash \(error)")
      }
    }, receiveValue: { (_, _, written) in
      totalWritten += written
    })
    
    wait(for: [expectation2], timeout: 1000)
    // Check total copied
    XCTAssertTrue(totalWritten == 11210638916, "Wrote \(totalWritten)")
  }
  
  // TODO func testSCPEmptyFile
  
  func testSCPDirectoryCopyFrom() throws {
    let config = SSHClientConfig(user: "carlos", authMethods: [AuthPassword(with: "")])
    
    let expectation = self.expectation(description: "scp")
    
    var connection: SSHClient?
    var sftp: SFTPClient?
    var scp: SCPClient?
    //var totalWritten = 0
    var filesWritten = 0
    
    let c1 = SSHClient.dial("localhost", with: config)
      .flatMap() { conn -> AnyPublisher<SCPClient, Error> in
        connection = conn
        return SCPClient.execute(using: conn, as: [.Sink, .Recursive], root: "/tmp/new")
      }.assertNoFailure()
      .sink { client in
        scp = client
        expectation.fulfill()
      }
    
    wait(for: [expectation], timeout: 15)
    
    var connectionSFTP: SSHClient?
    let expectation2 = self.expectation(description: "sftp")
    let c2 = SSHClient.dial("localhost", with: config)
      .flatMap() { conn -> AnyPublisher<SFTPClient, Error> in
        connectionSFTP = conn
        return conn.requestSFTP()
      }.flatMap { client -> AnyPublisher<Translator, Error> in
        sftp = client
        return sftp!.walkTo("playgrounds")
      }.flatMap { dir in
        return scp!.copy(from: [dir])
      }
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          expectation2.fulfill()
        case .failure(let error):
          // Problem here is we can have both SFTP and SSHError
          XCTFail("Crash \(error)")
        }
      }, receiveValue: { (name, size, progress) in
        print("\(name) - \(progress) of \(size)")
      })
    
    wait(for: [expectation2], timeout: 1000)
    //XCTAssertTrue(filesWritten > 0, "No files written")
    //XCTAssertTrue(totalWritten > 0, "Wrote \(totalWritten)")
  }
  
  // Copy path from scp to path on sftp
  func testCopyTo() throws {
    let config = SSHClientConfig(
      user: MockCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.password)]
    )
    
    let expectation = self.expectation(description: "scp")
    
    var connection: SSHClient?
    var sftp: SFTPClient?
    var scp: SCPClient?
    
    let c1 = SSHClient.dial(MockCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SCPClient, Error> in
        connection = conn
        return SCPClient.execute(using: conn, as: [.Source, .Recursive], root: "/Users/carlos/tmp/*")
      }
      .assertNoFailure()
      .sink { client in
        scp = client
        expectation.fulfill()
      }
    
    wait(for: [expectation], timeout: 15)
    
    let expectation2 = self.expectation(description: "sftp")
    let c2 = connection?
      .requestSFTP()
      .flatMap { client -> AnyPublisher<Translator, Error> in
      sftp = client
      return sftp!.walkTo("/tmp/test")
    }.flatMap { dir in
      return scp!.copy(to: dir)
    }
    .sink(receiveCompletion: { completion in
      switch completion {
      case .finished:
        expectation2.fulfill()
      case .failure(let error):
        // Problem here is we can have both SFTP and SSHError
        XCTFail("Crash \(error)")
      }
    }, receiveValue: { (name, size, progress) in
      print("\(name) - \(progress) of \(size)")
    })
    
    wait(for: [expectation2], timeout: 1000)
  }
}
