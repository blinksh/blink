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

extension String: Error {}

class SSHTests: XCTestCase {
  
  var cancellableBag: Set<AnyCancellable> = []
  
  override class func setUp() {
    SSHInit()
  }
  
  func testClient() throws {
    let connection = SSHClient
      .dialWithTestConfig()
      .lastOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished: break
          case .failure(let error):
            if let error = error as? SSHError {
              XCTFail(error.description)
              break
            }
            XCTFail("Unknown error")
          }
        })
    
    XCTAssertNotNil(connection)
  }
  
  func testClientCancel() throws {
    let c = SSHClient
      .dialWithTestConfig()
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Should not have completed the connection")
        case .failure(let error):
          if let error = error as? SSHError {
            XCTFail(error.description)
            break
          }
          XCTFail("Unknown error")
        }
      }, receiveValue: { conn in
        XCTFail("Should not have receive the connection")
      })
    
    c.cancel()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
    c.cancel()
  }
  
  // This test goes both for tryOperation and tryChannel, as the publisher is almost the same
  // This is more an implementation test than a functional one.
  func testClientCancelDuringTry() throws {
    let c = SSHClient
      .dial("192.168.1.15", with: .testConfig)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Should not have completed the connection")
        case .failure(let error):
          if let error = error as? SSHError {
            XCTFail(error.description)
            break
          }
          XCTFail("Unknown error")
        }
      }, receiveValue: { _ in
        XCTFail("Should not receive the connection")
      })
    
    let t = Thread {
      // Wait on block is half a second, so wait to trigger while the other thread
      // is currently blocked running the loop.
      usleep(3000)
      c.cancel()
    }
    t.start()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 5))
    t.cancel()
  }
  
  
  func testClientUnresolved() throws {
    continueAfterFailure = false
    throw XCTSkip("It is impossible to replicate reliably.")
    
    let expectConn = self.expectation(description: "Connection")
    
    
    var connection: SSHClient?
    let c = SSHClient.dialWithTestConfig()
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail()
        // Is it possible to repeat a test?
        //expectConn.fulfill()
        case .failure(let error):
          if let error = error as? SSHError {
            XCTFail(error.description)
            break
          }
          XCTFail("Unknown error")
        }
      }, receiveValue: { conn in
        connection = conn
      })
    
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
    print("CANCELLING===")
    c.cancel()
    // TODO We need to let the runloop run to close everything down?
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
    
    let c2 = SSHClient.dialWithTestConfig()
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Expected unresolved")
        // Is it possible to repeat a test?
        //expectConn.fulfill()
        case .failure(let error):
          XCTAssertTrue((error as? SSHError) != nil)
          expectConn.fulfill()
        }
      }, receiveValue: { conn in
        connection = conn
      })
    wait(for: [expectConn], timeout: 5)
    c2.cancel()
    // Check connection has been closed?
    // connection?.close()
  }
  
  func testConnectionTimeout() throws {
    // Dial an unknown host on same network, so it should timeout.
    // Note the result may be a bit unreliable.
    let config = SSHClientConfig(
      user: Credentials.timeoutHost.user,
      authMethods: [AuthPassword(with: Credentials.timeoutHost.password)],
      connectionTimeout: 3
    )
    
    let expectFail = self.expectation(description: "Time out")
    
    let connection = SSHClient
      .dial(Credentials.timeoutHost.host, with: config)
      .lastOutput(
        test: self,
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            XCTFail("Should not have succeeded")
          case .failure(let error):
            if let error = error as? SSHError {
              XCTAssertTrue((error.description.contains("timed out") || error.description.contains("Host is down")))
              expectFail.fulfill()
              
              break
            }
            XCTFail("Unknown error")
          }
        }
      )
    
    wait(for: [expectFail], timeout: 5)
    XCTAssertNil(connection)
  }
  
  /**
   Check if the currently connected host returns a valid formatted IP address.
   */
  func testGetConnectedIp() throws {
    // The connection pool should be maintained by the pool itself.
    // Restarting sessions though when required, should be done by the one using the sessions as a preference.
    
    // TODO Figure out errors better here, because otherwise this will be painful
    // TODO Maybe print the error during a catch, because that's really how errors will have to be processed.
    // TODO Connections are not stopped if cancelled. You can close the connection from outside, everything may subsequently
    // fail, but not be properly closed.
    // TODO: How does OpenSSH finish gracefully while connecting?
    let connection = SSHClient
      .dialWithTestConfig()
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
    let connectedIp = connection!.clientAddressIP()
    XCTAssertNotNil(connectedIp, "Failed to get connected IP address")
    XCTAssert(SSHUtils.isValidIP(address: connectedIp!), "Not a valid IP")
  }
  
  //    func testConnectionCancel() throws {
  //        let config = SSHClientConfig(user: MockCredentials.passwordCredentials.user, authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)])
  //
  //        let expectation = self.expectation(description: "Connection cancel")
  //
  //        var connection: SSHClient?
  //        let cancellable = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
  //            .sink(receiveCompletion: { completion in
  //                switch completion {
  //                case .finished:
  //                    break
  //                case .failure(let error):
  //                    // We should be able to capture an error.
  //                    if let error = error as? SSHError {
  //                        XCTFail(error.description)
  //                        break
  //                    }
  //                    XCTFail("Unknown error")
  //                }
  //            }, receiveValue: { conn in
  //                // TODO Depending on the case, we may not be able to test this properly. This could still fail if background
  //                // is prioritized over main.
  //                XCTFail("Connection should not have been established")
  //            }
  //        )
  //
  //        cancellable.cancel()
  //        //TODO Cancel is also called on dealloc
  //        // We may want to decide how we want to handle these cases because the auth will block a thread, even
  //        // after it was cancelled.
  //        waitForExpectations(timeout: 35, handler: nil)
  //    }
  
  
  func testInteractiveShellChannel() throws {
    // Create an interactive shell and close it. Note it is not enough to just
    // send an exit on the input, because otherwise we may be missing output. We
    // need to process all the output before the EOF and close are triggered.
    
    let expectClose = self.expectation(description: "PTY Closed")
    
    let connection = SSHClient
      .dialWithTestConfig()
      .exactOneOutput(test: self)!
    
    let stream = connection
      .requestInteractiveShell(withPTY: SSHClient.PTY(rows: 80, columns: 42))
      .assertNoFailure()
      .exactOneOutput(test: self)!
    
    stream.handleCompletion = expectClose.fulfill
    
    // Exit the remote session manually. Could also send a signal.
    let data = "exit\n".data(using: .utf8)!.withUnsafeBytes { DispatchData(bytes: $0) }

    var writeCompletion: Any? = nil
    stream.write(data, max: 20)
      .sink(
        test: self,
        receiveCompletion: {
          writeCompletion = $0
        }
      )
    
    assertCompletionFinished(writeCompletion)
    
    stream.connect(stdout: MemoryBuffer(fast: true))
    
    wait(for: [expectClose], timeout: 5)
  }
  
  func testExecChannel() throws {
    let cmd = "dd if=/dev/urandom bs=1024 count=10000 2> /dev/null"
    let expectation = self.expectation(description: "Buffer Written")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    print("=====First read")
    var cancellable = SSHClient.dialWithTestConfig()
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd)
      }
      .flatMap { s -> AnyPublisher<DispatchData, Error> in
        stream = s
        // Wait a little for the command to run and output to be available.
        //RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
        return s.read(max: 1024)
      }.assertNoFailure()
      .sink { buf in
        output = buf
        expectation.fulfill()
      }
    
    wait(for: [expectation], timeout: 500)
    XCTAssertTrue(output?.count == 1024)
    
    print("======Second read")
    let expectRestData = self.expectation(description: "Buffer Written")
    
    cancellable = stream!.read(max:SSIZE_MAX)
      .assertNoFailure()
      .sink { buf in
        output = buf
        expectRestData.fulfill()
      }
    
    wait(for: [expectRestData], timeout: 10)
    
    let remainingDataCount = (1024 * 10000) - 1024
    print(output?.count)
    XCTAssertTrue(output?.count == remainingDataCount, "Received \(output?.count), should have \(remainingDataCount)")
  }
  
  // NOTE This test requires to have the variable TEST as AcceptEnv at the host.
  func testEnvironment() throws {
    let key = "TEST"
    let val = "asdf"
    let cmd = "echo $\(key)"
    
    let expectation = self.expectation(description: "Test received")
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    var output: DispatchData?
    
    var cancellable = SSHClient.dialWithTestConfig()
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        print("Received Connection")
        connection = conn
        
        return conn.requestExec(command: cmd, withEnvVars: [key: val, "LANG": "en_US.UTF-8"])
      }
      .flatMap { s -> AnyPublisher<DispatchData, Error> in
        stream = s
        // Wait a little for the command to run and output to be available.
        //RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
        return s.read(max: 1024)
      }.assertNoFailure()
      .sink { buf in
        output = buf
        expectation.fulfill()
      }
    
    wait(for: [expectation], timeout: 2000)
    let str = String(decoding: output as AnyObject as! Data, as: UTF8.self)
    XCTAssertTrue(str == (val + "\n"))
  }
  
  func testSessionKill() throws {
    // This test is double.
    // First the entire connection is killed while we are running a command
    // This is seen as an "exception" in the connection, and we want to gracefully close everything.
    // Second the same command is allowed to run and we expect to finish after a reconnection.
    // This is supposed to emulate what in the future a "reconnect" would look like.
    
    var connection: SSHClient?
    var stream: SSH.Stream?
    let cmd = "sleep 5"
    let buffer = MemoryBuffer(fast: true)
    let expectConn = self.expectation(description: "Connection established")
    
    SSHClient.dialWithTestConfig()
      .assertNoFailure()
      .sink { conn in
        print("Received Connection")
        connection = conn
        expectConn.fulfill()
      }.store(in: &cancellableBag)
    
    wait(for: [expectConn], timeout: 5)
    
    let expectSessionKilled = self.expectation(description: "Sleep running")
    
    connection!.handleSessionException = { error in
      print("Exception received \(error)")
      stream?.cancel()
      stream = nil
      expectSessionKilled.fulfill()
    }
    
    connection!.requestExec(command: cmd).assertNoFailure().sink { s  in
      stream = s
      s.connect(stdout: buffer)
    }.store(in: &cancellableBag)
    
    var execStream: SSH.Stream?
    DispatchQueue.global(qos: .background)
      .asyncAfter(
        deadline: .now() + 3,
        execute: {
          // Kill ssh from the server side.
          // This is not a graceful termination. We expect an exception in the socket.
          connection!.requestExec(command: "kill $(ps -ef | grep notty | grep -v grep | awk '{print $2}')")
            .flatMap { s -> AnyPublisher<DispatchData, Error> in
              execStream = s
              return s.read(max: SSIZE_MAX)
            }
            .sink(receiveCompletion: { completion in
              switch completion {
              case .failure(let error as SSHError):
                print("Exec command also killed \(error)")
              case .failure(let error):
                XCTFail("Unknown error \(error)")
              default:
                break
              }
            }){ XCTAssertTrue($0.count == 0) }.store(in: &self.cancellableBag)
        })
    
    wait(for: [expectSessionKilled], timeout: 5)
    
    // Second part of the test
    connection!.requestExec(command: cmd).sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        print("Correctly failed to exec again \(error)")
      } else {
        XCTFail("New exec command on closed connection should have failed")
      }
    }, receiveValue: {_ in }).store(in: &cancellableBag)
    
    let newConnectionExpected = self.expectation(description: "New connection")
    SSHClient.dialWithTestConfig()
      .assertNoFailure()
      .sink { conn in
        print("Received Connection")
        connection = conn
        newConnectionExpected.fulfill()
      }.store(in: &cancellableBag)
    
    wait(for: [newConnectionExpected], timeout: 5)
    
    let expectCmdComplete = self.expectation(description: "Sleep completed")
    connection!.requestExec(command: cmd).assertNoFailure().sink { s in
      stream = s
      s.handleCompletion = {
        expectCmdComplete.fulfill()
      }
      s.connect(stdout: buffer)
    }.store(in: &cancellableBag)
    
    wait(for: [expectCmdComplete], timeout: 15)
  }
  
  // TODO To test tunnels, you could open a local connection and expose that on the other side.
  // https://fabianlee.org/2016/09/26/ubuntu-simulating-a-web-server-using-netcat/
  // Or maybe a simple server through network framework
}

class MemoryBuffer: Writer {
  var count = 0
  let fast: Bool
  let queue: DispatchQueue
  
  init(fast: Bool) {
    self.fast = fast
    self.queue = DispatchQueue(label: "test")
  }
  
  func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error> {
    return Just(buf.count).receive(on: self.queue).map { val in
      self.count += buf.count
      
      if !self.fast {
        sleep(1)
        //usleep(1000)
      }
      print("==== Wrote \(self.count)")
      
      print("Done")
      return val
    }.mapError { $0 as Error }.eraseToAnyPublisher()
  }
}

class RandomInputGenerator: Reader, WriterTo {
  let fast: Bool
  let queue = DispatchQueue(label: "randomgen")
  init(fast: Bool) {
    self.fast = fast
  }
  
  func read(max length: Int) -> AnyPublisher<DispatchData, Error> {
    // On SSIZE_MAX, we will be emitting an unlimited amount of blocks up to SSIZE_MAX
    var maxChunk: Int
    if length == SSIZE_MAX {
      maxChunk = 1024
    } else {
      maxChunk = length
    }
    
    var bytes = [Int8](repeating: 0, count: maxChunk)
    let status = SecRandomCopyBytes(kSecRandomDefault, maxChunk, &bytes)
    if status != errSecSuccess {
      return Fail(error: "Could generate random sequence" as! Error).eraseToAnyPublisher()
    }
    
    if length != SSIZE_MAX {
      var data = DispatchData.empty
      bytes.withUnsafeBytes { buf in
        data.append(buf)
      }
      
      // TODO Multiple dispatch objects
      return Just(data).mapError { $0 as Error }.eraseToAnyPublisher()
    }
    
    // In case of SSIZE_MAX, we just send data multiple times at different rates.
    return (0..<10).publisher
      .map { num in
        if !fast {
          sleep(1)
        }
        var data = DispatchData.empty
        bytes.withUnsafeBytes { buf in
          data.append(buf)
        }
        
        return data
      }.mapError {$0 as Error}.eraseToAnyPublisher()
  }
  
  func writeTo(_ w: Writer) -> AnyPublisher<Int, Error> {
    return read(max: SSIZE_MAX).receive(on: queue).print("Random Write")
      .flatMap(maxPublishers: .max(1)) {
        w.write($0, max: $0.count)
      }.eraseToAnyPublisher()
  }
}
