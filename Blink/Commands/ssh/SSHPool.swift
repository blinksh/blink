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


import Foundation
import Combine
import Dispatch

import BlinkConfig
import SSH


class SSHPool {
  static let shared = SSHPool()
  private var controls: [SSHClientControl] = []
  
  private init() {}

  static func dial(_ host: String, 
                   with config: SSHClientConfig, 
                   withControlMaster: ControlMasterOption = .no, 
                   withProxy proxy: SSH.SSHClient.ExecProxyCommandCallback? = nil) -> AnyPublisher<SSH.SSHClient, Error> {

    // Do not use an existing socket.
    if withControlMaster == .no {
      // TODO We may want a new socket, but still be able to manipulate it.
      // For now we will not allow that situation.
      return shared.startConnection(host, with: config, proxy: proxy, exposeSocket: false)
    }
    if let ctrl = shared.control(for: host, with: config) {
      if let conn = ctrl.connection, conn.isConnected {
        return .just(conn)
      } else {
        shared.removeControl(ctrl)
      }
    }
    
    return shared.startConnection(host, with: config, proxy: proxy)
  }

  private func startConnection(_ host: String, with config: SSHClientConfig,
                               proxy: SSH.SSHClient.ExecProxyCommandCallback? = nil,
                               exposeSocket exposed: Bool = true) -> AnyPublisher<SSH.SSHClient, Error> {
    let pb = PassthroughSubject<SSH.SSHClient, Error>()
    var dial: AnyCancellable?
    var runLoop: RunLoop!

    let t = Thread {
      runLoop = RunLoop.current

      dial = SSH.SSHClient.dial(host, with: config, withProxy: proxy)
        //.print("SSHClient Pool")
        .sink(
          receiveCompletion: { completion in
            pb.send(completion: completion)
          },
          receiveValue: { conn in
            let control = SSHClientControl(for: conn, on: host, with: config, running: runLoop, exposed: exposed)
            SSHPool.shared.controls.append(control)
            pb.send(conn)
          })

      SSH.SSHClient.run()
      print("Pool Thread out")
    }

    t.start()

    return pb.buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .handleEvents(receiveCancel: {
        dial = nil
      }).eraseToAnyPublisher()
  }

  static func connection(for host: String, with config: SSHClientConfig) -> SSH.SSHClient? {
    shared.control(for: host, with: config)?.connection
  }

  private static func control(on connection: SSH.SSHClient) -> SSHClientControl? {
    shared.controls.first { $0.connection === connection }
  }
  
  private func control(for host: String, with config: SSHClientConfig) -> SSHClientControl? {
    return controls.first { $0.isConnection(for: host, with: config) }
  }
  
  private func enforcePersistance(_ control: SSHClientControl) {
    print("Current channels \(control.numChannels)")
    print("\(control.localTunnels)")
    print("\(control.remoteTunnels)")
    if control.numChannels == 0 {
      self.removeControl(control)
    }
  }
}

extension SSHPool {
  static func deregister(allTunnelsForConnection connection: SSH.SSHClient) {
    guard let c = control(on: connection) else {
      return
    }

    c.localTunnels.forEach  { (k, _) in deregister(localForward: k, on: connection) }
    c.remoteTunnels.forEach { (k, _) in deregister(remoteForward: k, on: connection) }
    c.socks.forEach { (k, _) in deregister(socksBindAddress: k, on: connection) }

    // NOTE This is a workaround
    c.streams.forEach { (_, s) in s.cancel() }
    c.streams = []
  }
}

// Shell
extension SSHPool {
  static func register(shellOn connection: SSH.SSHClient) {
    // running command is not enough here to identify the connction as some information
    // may be predefined from Config.
    if let c = control(on: connection) {
      c.numShells += 1
    }
  }
  
  static func deregister(shellOn connection: SSH.SSHClient) {
    guard let c = control(on: connection) else {
      return
    }
    c.numShells -= 1
    shared.enforcePersistance(c)
  }
}

// Forward Tunnels
extension SSHPool {
  static func register(_ listener: SSHPortForwardListener, 
                       portForwardInfo: PortForwardInfo, 
                       on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.localTunnels[portForwardInfo] = listener
  }
  
  static func deregister(localForward: PortForwardInfo, on connection: SSH.SSHClient) {
    guard let c = control(on: connection) else {
      return
    }
    if let tunnel = c.localTunnels.removeValue(forKey: localForward) {
      tunnel.close()
    }
    shared.enforcePersistance(c)
  }

  static func contains(localForward: PortForwardInfo, on connection: SSH.SSHClient) -> Bool {
    guard let c = control(on: connection) else {
      return false
    }
    
    return c.localTunnels[localForward] != nil
  }
}

// Remote Tunnels
extension SSHPool {
  static func register(_ client: SSHPortForwardClient, 
                       portForwardInfo: PortForwardInfo, 
                       on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.remoteTunnels[portForwardInfo] = client
  }

  static func deregister(remoteForward: PortForwardInfo, on connection: SSH.SSHClient) {
    guard let c = control(on: connection) else {
      return
    }
    if let tunnel = c.remoteTunnels.removeValue(forKey: remoteForward) {
      tunnel.close()
    }
    shared.enforcePersistance(c)
  }

  static func contains(remoteForward: PortForwardInfo, on connection: SSH.SSHClient) -> Bool {
    guard let c = control(on: connection) else {
      return false
    }
    
    return c.remoteTunnels[remoteForward] != nil
  }
}

// Dynamic Forward
extension SSHPool {
  static func register(_ server: SOCKSServer,
                       bindAddressInfo: OptionalBindAddressInfo,
                       on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.socks[bindAddressInfo] = server
  }

  static func deregister(socksBindAddress: OptionalBindAddressInfo, on connection: SSH.SSHClient) {
    guard let c = control(on: connection) else {
      return
    }
    if let server = c.socks.removeValue(forKey: socksBindAddress) {
      server.close()
    }
    shared.enforcePersistance(c)
  }

  static func contains(socksBindAddress: OptionalBindAddressInfo, on connection: SSH.SSHClient) -> Bool {
    guard let c = control(on: connection) else {
      return false
    }
    
    return c.socks[socksBindAddress] != nil
  }
}

extension SSHPool {
  static func register(stdioStream stream: SSH.Stream, runningCommand command: SSHCommand, on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.streams.append((command, stream))
  }
  
  private func removeControl(_ control: SSHClientControl) {
    // For now, we just stop the connection as is
    // We could use a delegate just to notify when a connection is dead, and the control could
    // take care of figuring out when the connection it contains must go.
    guard
      let idx = controls.firstIndex(where: { $0 === control })
    else {
      return
    }
    
    // Removing references to connection to deinit.
    // We could also handle the pool with references to the connection.
    // But the shell or time based persistance may become more difficult.
    controls.remove(at: idx)
  }
}

fileprivate class SSHClientControl {
  var connection: SSH.SSHClient?
  let host: String
  let config: SSHClientConfig
  let runLoop: RunLoop
  let exposed: Bool
  
  var numShells: Int = 0
  //var shells: [(SSHCommand, SSH.Stream)] = []

  var localTunnels:  [PortForwardInfo:SSHPortForwardListener] = [:]
  var remoteTunnels: [PortForwardInfo:SSHPortForwardClient] = [:]
  var socks: [OptionalBindAddressInfo:SOCKSServer] = [:]

  var streams: [(SSHCommand, SSH.Stream)] = []

  var numChannels: Int {
    get {
      return numShells + streams.count + localTunnels.count + remoteTunnels.count + socks.count
    }
  }
  
  init(for connection: SSH.SSHClient, on host: String, with config: SSHClientConfig, running runLoop: RunLoop, exposed: Bool) {
    self.connection = connection
    self.host = host
    self.config = config
    self.runLoop = runLoop
    self.exposed = exposed
  }
  
  
  // Other parameters could specify how the connection should be treated by the pool
  // (timeouts, etc...)
  func isConnection(for host: String, with config: SSHClientConfig) -> Bool {
    // TODO equatable on config from API.
    if !self.exposed {
      return false
    }
    return self.host == host && config == self.config ? true : false
  }
}
/* 
fileprivate protocol TunnelControl {
  func close()
}

extension SSHPortForwardListener: TunnelControl {}

extension SSHPortForwardClient: TunnelControl {}
 */
extension PortForwardInfo: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.localPort)
    hasher.combine(self.bindAddress)
    hasher.combine(self.remotePort)
  }
}

extension OptionalBindAddressInfo: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.bindAddress)
    hasher.combine(self.port)
  }
}

