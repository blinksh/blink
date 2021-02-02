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

import Combine
import Dispatch
import Foundation
import Network

import LibSSH

public enum PortForwardState {
  case waiting(Error)
  case starting
  case ready
  /// Indicates operational error in the listener (a request error), but not full failure (tunnel is down)
  case error(Error)
}

public enum SSHPortForwardError: Error {
  case nwError(msg: String)
  
  public init(title: String, _ error: Error) {
    self = .nwError(msg: "PortForwardError - \(title) - \(error.localizedDescription)")
  }
}


public class SSHPortForwardListener {
  let client: SSHClient
  let host: String
  let localPort: NWEndpoint.Port
  let remotePort: NWEndpoint.Port
  var listener: NWListener?
  let queue: DispatchQueue
  var isReady = false
  var log: SSHLogger { get { client.log } }
  var cancellableBag: [AnyCancellable] = []
  
  var status = CurrentValueSubject<PortForwardState, Error>(.starting)
  
  var connections: [NWConnection] = []
  
  public init(on localPort: UInt16, toDestination host: String, on remotePort: UInt16, using client: SSHClient) {
    self.client = client
    self.host = host
    
    self.localPort = NWEndpoint.Port(integerLiteral: localPort)
    self.remotePort = NWEndpoint.Port(integerLiteral: remotePort)
    self.queue = DispatchQueue(label: "fwd-\(localPort)")
    
    self.start()
  }
  
  func start() {
    do {
      let lis = try NWListener(using: .tcp, on: self.localPort)
      self.listener = lis
    } catch {
      self.status.send(completion: .failure(SSHPortForwardError(title: "Could not initialize listener", error)))
      return
    }
    
    let listener = self.listener!
    listener.newConnectionHandler = handleConnection
    
    listener.stateUpdateHandler = { newState in
      self.log.message("State Updated \(newState)", SSH_LOG_INFO)
      self.isReady = false
      switch newState {
      case .ready:
        self.status.send(PortForwardState.ready)
        self.isReady = true
      case .failed(let error):
        // If the listener fails, re-start. This is an untested path.
        if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
          self.log.message("Restarting listener.", SSH_LOG_WARN)
          self.status.send(PortForwardState.waiting(error))
          listener.cancel()
          self.start()
        } else {
          self.log.message("Listener failed with \(error), stopping", SSH_LOG_WARN)
          self.status.send(completion: .failure(SSHPortForwardError(title: "Listener State Failed, stopping.", error)))
          self.close()
        }
      default:
        break
      }
      
    }
    
    listener.start(queue: self.queue)
  }
  
  public func connect() -> AnyPublisher<PortForwardState, Error> {
    return status.eraseToAnyPublisher()
  }
  
  func handleConnection(_ conn: NWConnection) {
    log.message("Received connection for tunnel", SSH_LOG_INFO)
    var stream: Stream?
    var cancellable: AnyCancellable?
    
    // Handle connection status, and tie the Stream to the connection.
    conn.stateUpdateHandler = { state in
      self.log.message("Forward connection received \(state)", SSH_LOG_DEBUG)
      
      switch state {
      case .ready:
        cancellable = self.client.requestForward(to: self.host,
                                                 port: Int32(self.remotePort.rawValue),
                                                 from: "localhost", localPort: Int32(self.localPort.rawValue))
          .sink(receiveCompletion: { c in
            if case let .failure(error) = c {
              self.log.message("Could not process Forward Request", SSH_LOG_WARN)
              self.status.send(PortForwardState.error(error))
            }
            // If the request for a tunnel worked, then the stream will have been received, so we
            // do not care about completion in this scenario.
          },
          receiveValue: { s in
            self.log.message("Forward received. Connecting to stream.", SSH_LOG_INFO)
            stream = s
            
            s.connect(stdout: conn, stdin: conn)
            s.handleCompletion = {
              self.closeConnection(conn)
              // Detach the stream, so we do not wait for the conn to be
              // released to free the channel.
              stream = nil
            }
            s.handleFailure = { error in
              // If the listener is already closed, then stop emitting failed messages.
              // This may happen as the connections close (connection closed by peer).
              if !self.isReady {
                return
              }
              self.closeConnection(conn)
              stream = nil
              self.status.send(PortForwardState.error(error))
            }
          })
        
      case .failed(let error):
        self.log.message("Connection state failed \(error)", SSH_LOG_WARN)
        self.status.send(completion: .failure(SSHPortForwardError(title: "Connection state failed", error)))
        self.closeConnection(conn)
        stream?.cancel()
        stream = nil
      case .cancelled:
        stream?.cancel()
        stream = nil
      default:
        break
      }
    }
    
    connections.append(conn)
    conn.start(queue: self.queue)
  }
  
  // Close will stop the listener, and no more connections will be accepted.
  // Open connections will be subsequently cancelled.
  public func close() {
    log.message("Closing Listener", SSH_LOG_INFO)
    if isReady {
      isReady = false
      self.status.send(completion: .finished)
      listener?.cancel()
      connections.forEach { $0.cancel() }
    }
  }
  
  func closeConnection(_ conn: NWConnection) {
    log.message("Closing Listener", SSH_LOG_DEBUG)
    conn.cancel()
    for (idx, c) in connections.enumerated() {
      if c === conn {
        connections.remove(at: idx)
      }
    }
  }
}

public class SSHPortForwardClient {
  let client: SSHClient
  let conn: NWConnection
  let queue: DispatchQueue
  let remotePort: NWEndpoint.Port
  
  var log: SSHLogger { get { client.log } }
  
  let status = CurrentValueSubject<PortForwardState, Error>(.starting)
  var isReady = false
  
  var reverseForward: AnyCancellable?
  
  // The listener is on the other side, here we just connect to a local port
  public init(forward address: String, onPort localPort: UInt16,
              toRemotePort remotePort: UInt16, using client: SSHClient) {
    let p = NWEndpoint.Port(integerLiteral: localPort)
    let host = NWEndpoint.Host(address)
    self.conn = NWConnection(host: host, port: p, using: .tcp)
    self.remotePort = NWEndpoint.Port(integerLiteral: remotePort)
    self.queue = DispatchQueue(label: "r-fwd-\(localPort)")
    self.client = client
  }
  
  public func connect() -> AnyPublisher<PortForwardState, Error> {
    // TODO Expose address to bind to on remote server
    // This is a different case than regular forward,
    // because here we serve the requests from the other side,
    // so the streams are received instead of generated here.
    var stream: Stream?
    
    self.conn.stateUpdateHandler = { state in
      self.log.message("Listener state Updated \(state)", SSH_LOG_INFO)
      self.isReady = false
      
      switch state {
      case .ready:
        self.status.send(PortForwardState.ready)
        self.isReady = true
        startReverse()
      case .waiting(let error):
        // Just notify, the connection itself will be reopened after a wait.
        self.status.send(PortForwardState.waiting(error))
      case .failed(let error):
        self.status.send(completion: .failure(SSHPortForwardError(title: "Connection state failed", error)))
      default:
        break
      }
    }
    
    func startReverse() {
      reverseForward = self.client.requestReverseForward(bindTo: nil, port: Int32(remotePort.rawValue))
        .sink(receiveCompletion: { completion in
          switch completion {
          // If the Reverse Forward is closed, then close the connection.
          case .finished:
            return self.close()
          case .failure(let error):
            self.status.send(completion: .failure(error))
            self.isReady = false
            self.close()
          }
        }, receiveValue: { s in
          self.log.message("Reverse stream received. Connecting stream", SSH_LOG_INFO)
          stream = s
          s.connect(stdout: self.conn, stdin: self.conn)
          s.handleCompletion = {
            stream = nil
          }
          s.handleFailure = { error in
            stream = nil
            self.status.send(.error(error))
          }
        })
    }
    
    self.conn.start(queue: queue)
    
    return status.eraseToAnyPublisher()
  }
  
  public func close() {
    log.message("Closing Reverse Forward", SSH_LOG_INFO)
    if isReady {
      reverseForward?.cancel()
      self.status.send(completion: .finished)
    }
    
    self.conn.cancel()
  }
}

extension NWConnection: WriterTo {
  public func writeTo(_ w: Writer) -> AnyPublisher<Int, Error> {
    let pub = PassthroughSubject<DispatchData, Error>()
    let sema = DispatchSemaphore(value: 0)
    
    func receiveLoop() {
      self.receive(minimumIncompleteLength: 1, maximumLength: Int(UINT32_MAX), completion: receiveData)
      //self.receiveMessage(completion: receiveData)
    }
    
    func receiveData(data: Data?, ctxt: ContentContext?, isComplete: Bool, rcvError: NWError?) {
      if let data = data {
        sema.wait()
        // Swift 5, Data is contiguous
        let dd = data.withUnsafeBytes {
          DispatchData(bytes: $0)
        }
        pub.send(dd)
      }
      
      if isComplete {
        pub.send(completion: .finished)
        return
      }
      
      if let error = rcvError {
        pub.send(completion: .failure(SSHPortForwardError(title: "Connection Reading error", error)))
      } else {
        self.queue?.async {
          receiveLoop()
        }
      }
    }
    
    return pub.handleEvents(
      receiveSubscription: { _ in receiveLoop() },
      // Nothing special to do on Cancel as this is just another stream.
      // receiveCancel: onCancel,
      receiveRequest: { _ in sema.signal() }
    ).flatMap(maxPublishers: .max(1)) { data in
      return w.write(data, max: data.count)
    }.eraseToAnyPublisher()
  }
}

extension NWConnection: Writer {
  public func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error> {
    let pub = PassthroughSubject<Int, Error>()
    
    // From https://gist.github.com/mayoff/6e35e263b9ddd04d9b77e5261212be19
    let data = buf as AnyObject as! Data
    return pub.handleEvents(
      receiveRequest: { _ in
        self.send(content: data, completion: SendCompletion.contentProcessed( { error in
          if let error = error {
            pub.send(completion: .failure(SSHPortForwardError(title: "Could not send data over Connection", error)))
            return
          }
          pub.send(buf.count)
          pub.send(completion: .finished)
        }))
      }
    ).eraseToAnyPublisher()
  }
}
