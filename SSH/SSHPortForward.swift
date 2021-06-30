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
    let listener: NWListener
    do {
      listener = try NWListener(using: .tcp, on: self.localPort)
    } catch {
      self.status.send(completion: .failure(SSHPortForwardError(title: "Could not initialize listener", error)))
      return
    }

    self.listener = listener
    listener.newConnectionHandler = { [weak self] in self?.handleConnectionUpdates($0) }
    listener.stateUpdateHandler = { [weak self] in self?.handleListenerUpdates($0) }
    
    listener.start(queue: self.queue)
  }
  
  public func connect() -> AnyPublisher<PortForwardState, Error> {
    return status.eraseToAnyPublisher()
  }
  
  // Await until the listener is binded and ready.
  public func ready() -> AnyPublisher<Void, Error> {
    return Future { promise in
      var c: AnyCancellable? = nil
      c = self.connect().sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          promise(.failure(error))
        case .finished:
          promise(.failure(SSHError(title: "Listener finished before bind.")))
        }
      }, receiveValue: { event in
        if case .ready = event {
          promise(.success(Void()))
          c?.cancel()
        }
      })
    }.eraseToAnyPublisher()
  }
  
  func handleListenerUpdates(_ newState: NWListener.State) {
    self.log.message("State Updated \(newState)", SSH_LOG_INFO)
    // self.isReady = false
    
    switch newState {
    case .ready:
      self.status.send(PortForwardState.ready)
      self.isReady = true
    case .failed(let error):
      // If the listener fails, re-start. This is an untested path.
      if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
        self.log.message("Restarting listener.", SSH_LOG_WARN)
        self.status.send(PortForwardState.waiting(error))
        self.isReady = false
        listener!.cancel()
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
  
  func handleConnectionUpdates(_ conn: NWConnection) {
    log.message("Received connection for tunnel", SSH_LOG_INFO)
    var stream: Stream?
    var cancellable: AnyCancellable?
    
    // Handle connection status, and tie the Stream to the connection.
    conn.stateUpdateHandler = { [weak self] state in
      guard let self = self else {
        return
      }
      
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
    log.message("Closing Port Forwarded Connection", SSH_LOG_INFO)
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
  let forwardHost: NWEndpoint.Host
  let localPort: NWEndpoint.Port
  let queue: DispatchQueue
  let remotePort: NWEndpoint.Port
  let bindAddress: String?

  var log: SSHLogger { get { client.log } }
  
  let status = CurrentValueSubject<PortForwardState, Error>(.starting)
  var isReady = false
  
  var reverseForward: AnyCancellable?
  var streams: [Stream] = []
  
  public init(forward address: String, onPort localPort: UInt16,
              toRemotePort remotePort: UInt16, bindAddress: String? = nil, using client: SSHClient) {
    self.localPort = NWEndpoint.Port(integerLiteral: localPort)
    self.forwardHost = NWEndpoint.Host(address)
    self.remotePort = NWEndpoint.Port(integerLiteral: remotePort)
    self.queue = DispatchQueue(label: "r-fwd-\(localPort)")
    self.bindAddress = bindAddress
    self.client = client
  }
  
  public func ready() -> AnyPublisher<Void, Error> {
    // This is a different case than regular forward,
    // because here we serve the requests from the other side,
    // so the streams are received instead of generated here.
    reverseForward = self.client.requestReverseForward(bindTo: bindAddress, port: Int32(remotePort.rawValue))
      .sink(
        receiveCompletion: { completion in
          switch completion {
            // If the Reverse Forward is closed, then close the connection.
          case .finished:
            return self.close()
          case .failure(let error):
            self.status.send(completion: .failure(error))
            self.isReady = false
            self.close()
          }
        },
        receiveValue: receive)
    
    return Future { promise in
      var c: AnyCancellable? = nil
      c = self.connect().sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          promise(.failure(error))
        case .finished:
          promise(.failure(SSHError(title: "Client finished before bind.")))
        }
      }, receiveValue: { event in
        if case .ready = event {
          promise(.success(Void()))
          c?.cancel()
        }
      })
    }.eraseToAnyPublisher()
  }
  
  public func connect() -> AnyPublisher<PortForwardState, Error> {
    return status.eraseToAnyPublisher()
  }
  
  public func close() {
    log.message("Closing Reverse Forward", SSH_LOG_INFO)
    if isReady {
      // Note we are not cancelling the already open connections
      reverseForward?.cancel()
      self.status.send(completion: .finished)
    }
  }
  
  private func receive(stream: Stream) {
    self.log.message("Reverse stream received. Establishing connection and piping stream", SSH_LOG_INFO)

    self.streams.append(stream)
    let conn = NWConnection(host: self.forwardHost, port: self.localPort, using: .tcp)
    conn.stateUpdateHandler = { (state: NWConnection.State) in
      self.log.message("Connection state Updated \(state)", SSH_LOG_INFO)
      self.isReady = false
      
      switch state {
      case .ready:
        // Notify that a connection has been established.
        self.status.send(PortForwardState.ready)
        self.isReady = true
      case .waiting(let error):
        // Just notify, the connection itself will be reopened after a wait.
        self.status.send(PortForwardState.waiting(error))
      case .failed(let error):
        self.status.send(completion: .failure(SSHPortForwardError(title: "Connection state failed", error)))
      default:
        break
      }
    }
    conn.start(queue: self.queue)
    stream.connect(stdout: conn, stdin: conn)

    func removeStream() {
      if let idx = self.streams.firstIndex(where: { stream === $0 }) {
        self.streams.remove(at: idx)
      }
    }
    stream.handleCompletion = {
      removeStream()
    }
    stream.handleFailure = { error in
      removeStream()
      self.status.send(.error(error))
    }
  }
}
