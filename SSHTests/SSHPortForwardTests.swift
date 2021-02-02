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
import Network

@testable import SSH

extension SSHTests {
  func testForwardPort() throws {
    self.continueAfterFailure = false
    
    let config = SSHClientConfig(user: MockCredentials.passwordCredentials.user,
                                 authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)],
                                 loggingVerbosity: .debug)
    var expectConnection = self.expectation(description: "Connected")
    let expectListenerClosed = self.expectation(description: "Listener Closed")
    
    var connection: SSHClient?
    var lis: SSHPortForwardListener?
    var url: URLSession? = URLSession(configuration: URLSessionConfiguration.default)
    
    SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .map() { conn -> SSHPortForwardListener in
        print("Received Connection")
        connection = conn
        
        lis = SSHPortForwardListener(
          on: 8080,
          toDestination: "www.guimp.com",
          on: 80,
          using: conn
        )
        
        return lis!
      }.flatMap { $0.connect() }
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          expectListenerClosed.fulfill()
        case .failure(let error):
          XCTFail("\(error)")
        }
      },
      receiveValue: { event in
        switch event {
        case .starting:
          print("Listener Starting")
        case .ready:
          expectConnection.fulfill()
        case .error(let error):
          XCTFail("\(error)")
        default:
          break
        }
      }).store(in: &cancellableBag)
    
    wait(for: [expectConnection], timeout: 15)
    
    let expectResponse = self.expectation(description: "Response received")
    
    // Launch a request on the port
    url!
      .dataTaskPublisher(for: URL(string: "http://localhost:8080")!)
      .assertNoFailure()
      .sink { element in
        guard let httpResponse = element.response as? HTTPURLResponse else {
          XCTFail("Bad server response")
          return
        }
        XCTAssert(httpResponse.statusCode == 200, "Wrong status code \(httpResponse.statusCode)")
        
        expectResponse.fulfill()
      }.store(in: &cancellableBag)
    
    wait(for: [expectResponse], timeout: 5)
    
    // A second request should succeed because URLSession keeps the connection
    // open in the pool, even if we got a result. expectResponse will only be called once (one stream only)
    
    let expectResponse2 = self.expectation(description: "Response received")
    // Launch a request on the port
    url!
      .dataTaskPublisher(for: URL(string: "http://localhost:8080")!)
      .assertNoFailure()
      .sink { element in
        guard let httpResponse = element.response as? HTTPURLResponse else {
          XCTFail("Bad server response")
          return
        }
        XCTAssert(httpResponse.statusCode == 200, "Wrong status code \(httpResponse.statusCode)")
        
        expectResponse2.fulfill()
      }.store(in: &cancellableBag)
    
    wait(for: [expectResponse2], timeout: 5)
    
    
    let expectResponse3 = self.expectation(description: "Response received")
    // Launch a request on the port
    URLSession.shared
      .dataTaskPublisher(for: URL(string: "http://localhost:8080")!)
      .assertNoFailure()
      .sink { element in
        guard let httpResponse = element.response as? HTTPURLResponse else {
          XCTFail("Bad server response")
          return
        }
        XCTAssert(httpResponse.statusCode == 200, "Wrong status code \(httpResponse.statusCode)")
        
        expectResponse3.fulfill()
      }.store(in: &cancellableBag)
    
    wait(for: [expectResponse3], timeout: 5)
    
    XCTAssertTrue(lis!.connections.count == 2, "Stream was not renewed the second time.")
    
    // Close the Tunnel and all open connections.
    lis!.close()
    wait(for: [expectListenerClosed], timeout: 5)
  }
  
  func testListenerPort() throws {
    self.continueAfterFailure = false
    
    let config = SSHClientConfig(user: MockCredentials.passwordCredentials.user,
                                 authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)])
    var expectConnection = self.expectation(description: "Connected")
    
    var connection: SSHClient?
    var lis: SSHPortForwardListener?
    
    SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .tryMap() { conn -> SSHPortForwardListener in
        print("Received Connection")
        connection = conn
        
        lis = SSHPortForwardListener(
          on: 8080,
          toDestination: "www.guimp.com",
          on: 80,
          using: conn
        )
        
        return lis!
      }.flatMap { $0.connect() }
      .compactMap { event -> AnyPublisher<Void, Error>? in
        switch event {
        case .starting:
          print("Listener Starting")
          return nil
        case .ready:
          print("Listener Ready")
          expectConnection.fulfill()
          return nil
        default:
          return nil
        }
      }.assertNoFailure()
      .sink {_ in }.store(in: &cancellableBag)
    
    wait(for: [expectConnection], timeout: 15)
    
    // A second listener should fail when started on same port.
    let expectFailure = self.expectation(description: "Connected")
    
    let lis2 = SSHPortForwardListener(on: 8080, toDestination: "www.google.com", on: 80, using: connection!)
    //lis2.start()
    lis2.connect().tryMap { event in
      print("Listener sent \(event)")
    }.sink (receiveCompletion: {completion in
      switch completion {
      case .failure(let error):
        print("\(error)")
        expectFailure.fulfill()
      case .finished:
        XCTFail("Listener should not have started")
      }
    }, receiveValue: {}).store(in: &cancellableBag)
    
    wait(for: [expectFailure], timeout: 15)
    
  }
  
  func testReverseForwardPort() throws {
    // We test it by doing the same as the forward, but on the other side.
    // So instead of a URLRequest, execute a command on the "server"
    // calling the routed port.
    // curl -o /dev/null -s -w "%{http_code}\n" http://localhost
    self.continueAfterFailure = false
    
    let config = SSHClientConfig(user: MockCredentials.passwordCredentials.user, authMethods: [AuthPassword(with: MockCredentials.passwordCredentials.password)])
    let expectConnection = self.expectation(description: "Connected")
    let expectStream = self.expectation(description: "Stream received")
    
    var connection: SSHClient?
    
    var client: SSHPortForwardClient?
    
    let c = SSHClient.dial(MockCredentials.passwordCredentials.host, with: config)
      .tryMap() { conn -> SSHPortForwardClient in
        print("Received Connection")
        connection = conn
        
        client = SSHPortForwardClient(forward: "www.guimp.com", onPort: 80,
                                      toRemotePort: 8080, using: conn)
        return client!
      }.flatMap { $0.connect() }
      .assertNoFailure()
      .sink { event in
        print("Received \(event)")
        switch event {
        case .ready:
          expectConnection.fulfill()
        case .error(let error):
          XCTFail("\(error)")
        default:
          break
        }
      }
    
    wait(for: [expectConnection], timeout: 5000)
    
    var cmd: SSH.Stream?
    let cancelRequest = connection!.requestExec(command: "curl -o /dev/null -s -w \"%{http_code}\n\" localhost:8080")
      .flatMap { stream -> AnyPublisher<DispatchData, Error> in
        cmd = stream
        return stream.read(max: SSIZE_MAX)
      }
      .assertNoFailure()
      .sink { buf in
        let output = String(data: buf as AnyObject as! Data, encoding: .utf8)
        // Output may be 000 in case the channel did not succeed.
        XCTAssert(output == "200\n")
        expectStream.fulfill()
      }
    wait(for: [expectStream], timeout: 500)
    
    // Closing up stuff. Sometimes there may be a callback or error of some kind because we got rid of some object.
    client!.close()
  }
  
  func testProxyCommand() throws {
    let config = SSHClientConfig(user: "carlos",
                                 proxyJump: "localhost",
                                 //proxyCommand: "ssh -W %h:%p localhost",
                                 authMethods: [AuthPassword(with: "")])
    
    let configProxy = SSHClientConfig(user: "carlos",
                                      authMethods: [AuthPassword(with: "")])
    
    let expectConnection = self.expectation(description: "Connected")
    let expectExecFinished = self.expectation(description: "Exec finished")
    let expectConnClosed = self.expectation(description: "Main connection closing the proxy")
    let expectThreadExit = self.expectation(description: "Exit thread")
    // The callback could be async scheduled, because it will anyway have to
    // figure out things with the socket. But we have to retain it somehow.
    var proxyCancellable: AnyCancellable?
    let execProxyCommand: SSHClient.ExecProxyCommandCallback = { (command, sockIn, sockOut) in
      // Needs to start a tunnel to the destination, which
      // should be specified at the command.
      // The tunnel is then mapped to the socket.
      // If running a command, we would just map stdio and run the command.
      let t = Thread(block: {
        let destination = "localhost"
        let destinationPort = 22
        var stream: SSH.Stream?
        
        let output = DispatchOutputStream(stream: sockOut)
        let input = DispatchInputStream(stream: sockIn)
        var connection: SSHClient?
        
        proxyCancellable = SSHClient.dial("localhost", with: configProxy)
          .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
            connection = conn
            return conn.requestForward(to: destination, port: Int32(destinationPort), from: "localhost", localPort: 22)
          }.sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
              break
            case .failure(let error as SSHError):
              XCTFail(error.description)
            // Closing the socket should also close the other connection
            case .failure(let error):
              XCTFail("Unknown error - \(error)")
            }
          }, receiveValue: { s in
            stream = s
            s.handleCompletion = {
              expectConnClosed.fulfill()
            }
            // Uncomment if you want to delay the other connection.
            // Interesting to see how the other one will just try again the Connect.
            //RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
            s.connect(stdout: output, stdin: input)
          })
        self.wait(for: [expectExecFinished], timeout: 5)
        
        // Now we await here for the main connection to close.
        // Closing the main connection should close the proxy as well.
        self.wait(for: [expectConnClosed], timeout: 5)
        
        expectThreadExit.fulfill()
      })
      t.start()
    }
    
    var connection: SSHClient?
    
    let testCommand = "echo hello"
    var output: DispatchData?
    var cancellable = SSHClient.dial("localhost", with: config, withProxy: execProxyCommand)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        connection = conn
        return conn.requestExec(command: testCommand)
      }
      .flatMap {
        $0.read(max: 6)
      }
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          expectConnection.fulfill()
        case .failure(let error as SSHError):
          XCTFail(error.description)
        case .failure(let error):
          XCTFail("Unknown error - \(error)")
        }
        
      }, receiveValue: { buf in
        output = buf
      })
    
    wait(for: [expectConnection], timeout: 500)
    expectExecFinished.fulfill()
    
    // Properly wrapping things up, simulating what an app would do.
    // Just closing the main connection should close the proxy.
    connection = nil
    wait(for: [expectThreadExit], timeout: 500)
    
    XCTAssertTrue(output?.count == 6, "Not received all bytes for 'hello\n'")
  }
  
  func testProxyCommandConnFailure() throws {
    // The proxy will not be able to authenticate, and this should trigger
    // an error during connection, because we won't be able to establish it.
    var config = SSHClientConfig(user: "carlos",
                                 proxyJump: "localhost",
                                 //proxyCommand: "ssh -W %h:%p localhost",
                                 authMethods: [AuthPassword(with: "")])
    
    let expectFailure = self.expectation(description: "Connection should fail")
    // The callback could be async scheduled, because it will anyway have to
    // figure out things with the socket. But we have to retain it somehow.
    var proxyCancellable: AnyCancellable?
    let execProxyCommand: SSHClient.ExecProxyCommandCallback = { (command, sockIn, sockOut) in
      let t = Thread(block: {
        // Wait and close the socket. Note that if a connection
        // fails, that is what a CLI would do.
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        close(sockIn)
        close(sockOut)
      })
      t.start()
    }
    
    var connection: SSHClient?
    
    var cancellable = SSHClient.dial("localhost",
                                     with: config, withProxy: execProxyCommand)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          XCTFail("Connection should not have succeeded with no proxy socket")
        case .failure(let error as SSHError):
          print("Correctly received error: \(error)")
          expectFailure.fulfill()
        case .failure(let error):
          XCTFail("Unknown error - \(error)")
        }
        
      }, receiveValue: { _ in })
    
    wait(for: [expectFailure], timeout: 500)
  }
  
  // TODO Come back to this after adding TCP Keep Alive packets
  // The other side of the stream will be happy to think everything works
  // when the other side is idle.
  // https://blog.stephencleary.com/2009/05/detection-of-half-open-dropped.html
  // https://stackoverflow.com/questions/34615807/nsstream-delegate-not-firing-errors
  func testProxyCommandStreamFailure() throws {
    throw XCTSkip("Suspect issue with NSInputStream. Not receiving EOF events.")
    // Killing the proxy should close the connection, and if handling
    // the stream properly, it should be closed as well. And that in a
    // chain should make everything else receive a close as well, probably
    // at the session level.
    // This test may be necessary to see how the flow of errors would work.
    var config = SSHClientConfig(user: "carlos",
                                 proxyJump: "localhost",
                                 //proxyCommand: "ssh -W %h:%p localhost",
                                 authMethods: [AuthPassword(with: "")],
                                 loggingVerbosity: .debug)
    
    let destination = "localhost"
    let destinationPort = 22
    let configProxy = SSHClientConfig(user: "carlos",
                                      authMethods: [AuthPassword(with: "")])
    
    let expectConnection = self.expectation(description: "Connected")
    let expectExecFinished = self.expectation(description: "Exec finished")
    let expectConnFailure = self.expectation(description: "Main connection received failure")
    let expectThreadExit = self.expectation(description: "Exit thread")
    let expectEOF = self.expectation(description: "EOF")
    
    var proxyCancellable: AnyCancellable?
    let execProxyCommand: SSHClient.ExecProxyCommandCallback = { (command, sockIn, sockOut) in
      // Needs to start a tunnel to the destination, which
      // should be specified at the command.
      // The tunnel is then mapped to the socket.
      // If running a command, we would just map stdio and run the command.
      let t = Thread(block: {
        var stream: SSH.Stream?
        
        var output: DispatchOutputStream? = DispatchOutputStream(stream: dup(sockOut))
        var input: DispatchInputStream? = DispatchInputStream(stream: dup(sockIn))
        var connection: SSHClient?
        
        proxyCancellable = SSHClient.dial(destination, with: configProxy)
          .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
            connection = conn
            return conn.requestForward(to: destination, port: Int32(destinationPort), from: destination, localPort: 22)
          }.sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
              break
            case .failure(let error as SSHError):
              XCTFail(error.description)
            // Closing the socket should also close the other connection
            case .failure(let error):
              XCTFail("Unknown error - \(error)")
            }
          }, receiveValue: { s in
            stream = s
            s.handleCompletion = {
              print("Complete")
            }
            s.handleFailure = { error in
              print("Failed")
            }
            s.connect(stdout: output!, stdin: input!)
          })
        
        self.wait(for: [expectExecFinished], timeout: 5)
        
        connection?.rloop.run(until: Date(timeIntervalSinceNow: 2))
        //                output?.close()
        //                input?.close()
        
        // Close the channel
        stream?.cancel()
        stream?.sendEOF().assertNoFailure().sink { _ in
          expectEOF.fulfill()
        }
        .store(in: &self.cancellableBag)
        //
        self.wait(for: [expectEOF], timeout: 500)
        stream?.cancel()
        stream = nil
        connection = nil
        
        close(sockIn)
        close(sockOut)
        self.wait(for: [expectConnFailure], timeout: 500)
        
        //expectThreadExit.fulfill()
      })
      t.start()
    }
    
    var connection: SSHClient?
    
    let testCommand = "du /"
    var output: DispatchData?
    var stream: SSH.Stream?
    let buffer = MemoryBuffer(fast: true)
    
    var cancellable = SSHClient.dial("localhost", with: config, withProxy: execProxyCommand)
      .flatMap() { conn -> AnyPublisher<SSH.Stream, Error> in
        connection = conn
        return conn.requestExec(command: testCommand)
      }.assertNoFailure()
      .sink { s in
        stream = s
        s.handleFailure = { error in
          print("Captured error on Main SSH \(error)")
          expectConnFailure.fulfill()
        }
        s.handleCompletion = {
          print("Main connection Completed")
        }
        expectExecFinished.fulfill()
        // We expect this will not return, but want to capture an error
        s.connect(stdout: buffer)
      }
    
    wait(for: [expectThreadExit], timeout: 500)
  }
}
