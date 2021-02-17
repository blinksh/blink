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
import LibSSH

@testable import SSH

extension SSHTests {
  func testStreamConnect() throws {
    
    let cmd = "dd if=/dev/urandom bs=1024 count=10000 2> /dev/null"
    let expectation = self.expectation(description: "Buffer Written")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    let buffer = MemoryBuffer(fast: false)
    
    var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: .testConfig)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s  in
        stream = s
        s.handleCompletion = { expectation.fulfill() }
        s.connect(stdout: buffer)
      }
    
    wait(for: [expectation], timeout: 15)
    XCTAssertTrue(buffer.count == (1024 * 10000), "Buffer does not match. Got \(buffer.count)")
    
    let fastExpectation = self.expectation(description: "Buffer Written")
    let fastBuffer = MemoryBuffer(fast: true)
    
    print("FAST WRITE===")
    cancellable = Just(connection!)
      .mapError {$0 as Error}
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s in
        stream = s
        s.handleCompletion = { fastExpectation.fulfill() }
        s.connect(stdout: fastBuffer)
      }
    
    wait(for: [fastExpectation], timeout: 15)
    XCTAssertTrue(fastBuffer.count == (1024 * 10000), "Buffer does not match. Got \(fastBuffer.count)")
  }
  
  func testInStream() throws {
    // Write at different rates, be able to gather the full output, maybe a command like "cat"
    // Trigger windowed writes and continous usage of active windows.
    // Use data from the previous stdout to do stdin. Handle writes at different rates with the Buffer.
    // We can adjust the windows on buffer as we see it here.
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)],
      loggingVerbosity: .debug
    )
    let expectation = self.expectation(description: "Buffer Written")
    let cmd = "cat"
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    var written = 0
    let expectedBytes = 1024 * 10
    
    let buffer = MemoryBuffer(fast: true)
    let input = RandomInputGenerator(fast: true)
    
    // TODO Maybe we have to read too, so that the flow continuous moving.
    // It may not be enough with writing only if things are accumulating.
    SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s in
        stream = s
        s.handleCompletion = {
          expectation.fulfill()
        }
        s.connect(stdout: buffer, stdin: input)
      }.store(in: &cancellableBag)
    
    wait(for: [expectation], timeout: 5)
    XCTAssertTrue(stream?.stdinBytes == expectedBytes, "Received \(stream?.stdinBytes). Should have \(expectedBytes)")
  }
  
  func testErrStream() throws {
    // Read on Error Stream, while nothing is received on stdout.
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)]
    )
    let cmd = "dd if=/dev/urandom bs=1024 count=1000 status=none 1>&2"
    let expectation = self.expectation(description: "Buffer Written")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    let buffer = MemoryBuffer(fast: true)
    let errBuffer = MemoryBuffer(fast: true)
    
    var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s  in
        stream = s
        s.handleCompletion = { expectation.fulfill() }
        s.connect(stdout: buffer, stderr: errBuffer)
      }
    
    wait(for: [expectation], timeout: 15)
    XCTAssertTrue(buffer.count == 0, "Buffer does not match. Got \(buffer.count)")
    XCTAssertTrue(errBuffer.count == 1024*1000, "ErrBuffer does not match. Got \(errBuffer.count)")
  }
  
  // We will leave a long running stream, and will stop it in the middle of
  // an operation. If we then tried to perform another operation on it,
  // it should fail.
  func testOutStreamStop() throws {
    let cmd = "du /"
    
    let expectCancel = self.expectation(description: "Operation Cancelled")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    let buffer = MemoryBuffer(fast: true)
    
    let cancellable = SSHClient.dial("localhost", with: .testConfig)
      //var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s  in
        stream = s
        s.connect(stdout: buffer)
      }
    
    DispatchQueue.global(qos: .background)
      .asyncAfter(deadline: .now() + 3,
                  execute: {
                    print("=== Cancel stream")
                    stream!.cancel()
                    expectCancel.fulfill()
                  })
    wait(for: [expectCancel], timeout: 6)
    
    let channel = stream!.channel
    weak var s = stream
    stream = nil
    XCTAssertNil(s)
    connection?.rloop.run(until: Date(timeIntervalSinceNow: 1))
    sleep(1)
    XCTAssertTrue(ssh_channel_is_closed(channel) != 0)
    cancellable.cancel()
  }
  
  // Random input from a stream to a file that will be stopped right in the middle.
  func testInStreamStop() throws {
    let cmd = "cat > /tmp/asdf"
    
    let expectCancel = self.expectation(description: "Operation Cancelled")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    let buffer = MemoryBuffer(fast: true)
    
    let cancellable = SSHClient.dial("localhost", with: .testConfig)
      //var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }.flatMap { s -> AnyPublisher<DispatchData, Error> in
        stream = s
        let input = RandomInputGenerator(fast: false)
        return input.read(max: 1024 * 10000)
      }.flatMap { stream!.write($0, max: $0.count) }
      .assertNoFailure().sink { count in
        print("Wrote \(count)")
      }
    
    DispatchQueue.global(qos: .background)
      .asyncAfter(deadline: .now() + 5,
                  execute: {
                    cancellable.cancel()
                    expectCancel.fulfill()
                  })
    wait(for: [expectCancel], timeout: 20)
    
    let channel = stream!.channel
    weak var s = stream
    stream = nil
    XCTAssertNil(s)
    // Let the runloop progress and then check that everything fell through properly.
    connection?.rloop.run(until: Date(timeIntervalSinceNow: 1))
    sleep(1)
    XCTAssertTrue(ssh_channel_is_closed(channel) != 0)
    cancellable.cancel()
  }
  
  func testStreamEOF() throws {
    
    let cmd = "cat"
    
    let expectCancel = self.expectation(description: "Operation Cancelled")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    let buffer = MemoryBuffer(fast: true)
    
    var cancellable = SSHClient.dial(MockCredentials.host, with: .testConfig)
      //var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s  in
        stream = s
        s.handleCompletion = { expectCancel.fulfill() }
        s.connect(stdout: buffer)
      }
    
    DispatchQueue.global(qos: .background)
      .asyncAfter(deadline: .now() + 5,
                  execute: {
                    stream?.sendEOF().assertNoFailure()
                      .sink {}.store(in: &self.cancellableBag)
                  })
    wait(for: [expectCancel], timeout: 4000)
  }
  
  func testInstreamClose() throws {
    // This is similar to the EOF test, but finishing writes from the connected
    // stream should have the same effect.
    
    let cmd = "cat"
    
    let expectCancel = self.expectation(description: "Operation Cancelled")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    let buffer = MemoryBuffer(fast: true)
    
    var cancellable = SSHClient.dial("localhost", with: .testConfig)
      //var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }.assertNoFailure()
      .sink { s  in
        stream = s
        s.handleCompletion = { expectCancel.fulfill() }
        s.connect(stdout: buffer)
      }
    
    DispatchQueue.global(qos: .background)
      .asyncAfter(deadline: .now() + 4,
                  execute: {
                    stream?.sendEOF().assertNoFailure()
                      .sink {}.store(in: &self.cancellableBag)
                  })
    wait(for: [expectCancel], timeout: 14)
  }
  
  
  func testStreamCloseRemote() throws {
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)]
    )
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    
    let buffer = MemoryBuffer(fast: true)
    
    let expectConn = self.expectation(description: "Connection established")
    
    let expectKill = self.expectation(description: "Session killed from remote")
    
//    var cancellable = SSHClient.dial("192.170.1.100", with: config)
    var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        return conn.requestExec(command: "sleep 1000")
      }
      .sink(receiveCompletion: {completion in
        switch completion {
        case .failure(let error as SSHError):
          XCTFail(error.description)
        default:
          break
        }
      }, receiveValue: { s  in
        s.handleCompletion = { expectKill.fulfill() }
        stream = s
        s.connect(stdout: buffer)
        expectConn.fulfill()
      })
    wait(for: [expectConn], timeout: 10)
    
    var execStream: SSH.Stream?
    
    DispatchQueue.global(qos: .background)
      .asyncAfter(
        deadline: .now() + 1,
        execute: {
          // Abruptly terminate the command from the server side.
          // Note for ssh is a graceful termination.
          connection!.requestExec(command: "killall sleep")
            //                connection!.requestExec(command: "kill $(ps -ef | grep sleep | grep -v grep | awk '{print $2}')")
            .flatMap { s -> AnyPublisher<DispatchData, Error> in
              execStream = s
              return s.read(max: SSIZE_MAX)
            }
            .assertNoFailure()
            // Nothing should have been read, but the read
            // must return as well.
            .sink { XCTAssertTrue($0.count == 0) }.store(in: &self.cancellableBag)
        })
    
    wait(for: [expectKill], timeout: 10)
  }
  
  // In this case the stream is connected to a pipe. In case the pipe closes, the stream needs to finalize.
  // This tries to imitate what happens at the terminal level with a proxy connection.
  func testStreamToPipe() throws {
    let config = SSHClientConfig(
      user: MockCredentials.passwordCredentials.user,
      port: MockCredentials.port,
      authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)],
      loggingVerbosity: .trace
    )
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    
    let expectConn = self.expectation(description: "Connection established.")
    let expectCompletion = self.expectation(description: "Stream completed.")
    
    var outstream: DispatchOutputStream?
    var instream: DispatchInputStream?
    
    var fdIn: [Int32] = [-1, -1]
    var fdOut: [Int32] = [-1, -1]
    if pipe(&fdIn) != 0 {
      throw "pipe() failed, \(String(validatingUTF8: strerror(errno)) ?? "")"
    }
    if pipe(&fdOut) != 0 {
      throw "pipe() failed, \(String(validatingUTF8: strerror(errno)) ?? "")"
    }
    
    
    var cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        return conn.requestForward(to: "localhost", port: 22, from: "stdio", localPort: 22)
        //return conn.requestInteractiveShell()
      }
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error as SSHError):
          XCTFail(error.description)
        default:
          break
        }
      }, receiveValue: { s  in
        s.handleCompletion = {
          expectCompletion.fulfill()
          
        }
        s.handleFailure = { err in
          XCTFail("\(err)")
        }
        stream = s
        outstream = DispatchOutputStream(stream: fdOut[1])
        instream = DispatchInputStream(stream: fdIn[0])
        s.connect(stdout: outstream!, stdin: instream!)
        expectConn.fulfill()
      })
    wait(for: [expectConn], timeout: 10)
    close(fdIn[1])
    
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
    let n = read(fdOut[0], buffer, 1024)
    if n > 0 {
      let data = String(cString: buffer)
      print("\(data)")
    }
    
    wait(for: [expectCompletion], timeout: 30000)
    
    // Closing Dispatch first and then the underlying descriptor.
    outstream?.close()
    instream?.close()
    close(fdIn[1])
    close(fdOut[0])
    close(fdOut[1])
  }
}
