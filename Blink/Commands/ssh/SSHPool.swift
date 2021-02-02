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

import SSH


class SSHPool {
  static let shared = SSHPool()
  private var controls: [SSHClientControl] = []
  
  private init() {}

  static func dial(_ host: String, with config: SSHClientConfig, connectionOptions options: ConfigFileOptions, withProxy proxy: SSH.SSHClient.ExecProxyCommandCallback? = nil) -> AnyPublisher<SSH.SSHClient, Error> {
    // Do not use an existing socket.
    if !options.controlMaster {
      // TODO We may want a new socket, but still be able to manipulate it.
      // For now we will not allow that situation.
      return shared.startConnection(host, with: config, proxy: proxy, exposeSocket: false)
    }
    guard let conn = connection(for: host, with: config) else {
      return shared.startConnection(host, with: config, proxy: proxy)
    }
    return Just(conn).mapError { $0 as Error }.eraseToAnyPublisher()
  }

  private func startConnection(_ host: String, with config: SSHClientConfig,
                               proxy: SSH.SSHClient.ExecProxyCommandCallback? = nil,
                               exposeSocket exposed: Bool = true) -> AnyPublisher<SSH.SSHClient, Error> {
    let pb = PassthroughSubject<SSH.SSHClient, Error>()
    var cancel: AnyCancellable?
    var runLoop: RunLoop?

    let t = Thread {
      runLoop = RunLoop.current

      cancel = SSH.SSHClient.dial(host, with: config, withProxy: proxy)
        .sink(receiveCompletion: { pb.send(completion: $0) },
              receiveValue: { conn in
                let control = SSHClientControl(for: conn, on: host, with: config, running: runLoop!, exposed: exposed)
                SSHPool.shared.controls.append(control)
                pb.send(conn)
        })

      await(runLoop: runLoop!)
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
      print("Pool Thread out")
    }

    t.start()

    return pb.buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .handleEvents(receiveCancel: {
        cancel?.cancel()
      }).eraseToAnyPublisher()
  }

  static func connection(for host: String, with config: SSHClientConfig) -> SSH.SSHClient? {
    shared.control(for: host, with: config)?.connection
  }
  
  static func register(shellOn connection: SSH.SSHClient) {
    // running command is not enough here to identify the connction as some information
    // may be predefined from Config.
    let c = control(on: connection)
    c?.numShells += 1
  }
  
  static func register(_ listener: SSHPortForwardListener, runningCommand command: SSHCommand, on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.tunnelListeners.append((command, listener))
  }

  static func register(_ client: SSHPortForwardClient, runningCommand command: SSHCommand, on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.tunnelClients.append((command, client))
  }
  
  static func register(stdioStream stream: SSH.Stream, runningCommand command: SSHCommand, on connection: SSH.SSHClient) {
    let c = control(on: connection)
    c?.streams.append((command, stream))
  }
  
  // TODO connection won't be deinited if you are still keeping a reference.
  // I care about the channel, everything else should not be an issue.
  static func deregister(runningCommand command: SSHCommand, on connection: SSH.SSHClient) {
    // Attach Commands to possibly running sessions
    // Command - tunnel, reverse, session. CommandControl.
    // Session Control - for a connection, has multiple CommandControls.
    // TODO Avoid enforcing !
    guard let c = control(on: connection) else {
      // TODO Should we throw?
      return
    }
    c.deregister(command)
    shared.enforcePersistance(c)
  }
  
  private static func control(on connection: SSH.SSHClient) -> SSHClientControl? {
    shared.controls.first { $0.connection === connection }
  }
  
  private func control(for host: String, with config: SSHClientConfig) -> SSHClientControl? {
    return controls.first { $0.isConnection(for: host, with: config) }
  }
  
  private func enforcePersistance(_ control: SSHClientControl) {
    if control.numChannels == 0 {
      // For now, we just stop the connection as is
      // We could use a delegate just to notify when a connection is dead, and the control could
      // take care of figuring out when the connection it contains must go.
      awake(runLoop: control.runLoop)
      let idx = controls.firstIndex { $0 === control }!
      
      // Removing references to connection to deinit.
      // We could also handle the pool with references to the connection.
      // But the shell or time based persistance may become more difficult.
      controls.remove(at: idx)
    }
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
  var tunnelListeners: [(SSHCommand, SSHPortForwardListener)] = []
  var tunnelClients: [(SSHCommand, SSHPortForwardClient)] = []
  var streams: [(SSHCommand, SSH.Stream)] = []
  var numChannels: Int {
    get {
      return numShells + streams.count + tunnelListeners.count + tunnelClients.count
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
    return self.host == host ? true : false
  }
  
  func deregister(_ command: SSHCommand) {
    if command.startsSession {
      // There is no way to stop a specific shell from remote, as they are not identified,
      // so we just keep them as numbers.
      // TODO Test force closing the connection will not mess up with the stream.
      // We may want to take care of the stream here as well.
      numShells -= 1
    }
    
    // TODO This may not look very good when we start multiple sessions
    // on the same server. We will need multiple connections, and deinstancing the right ones. When do you deregister?
    if let stdio = command.stdioHostAndPort,
       let idx = streams.firstIndex(where: { (c, _) in c.stdioHostAndPort == stdio }) {
      let (_, stream) = streams.remove(at: idx)
      //let (_, stream) = streams[idx]
      stream.cancel()
    }
    
    // Remove the tunnels
    // TEST Once the tunnels are deinitalized, they shoul also be closed.
    // TODO We should not need the close but will enforce it.
    if let tunnel = command.localPortForward,
       let idx = self.tunnelListeners.firstIndex(where: { (t, _) in t.localPortForward == tunnel }) {
      let (_, lis) = tunnelListeners.remove(at: idx)
      lis.close()
    }
    if let tunnel = command.reversePortForward,
       let idx = self.tunnelClients.firstIndex(where: { (t, _) in t.reversePortForward == tunnel }) {
      let (_, cli) = tunnelClients.remove(at: idx)
      cli.close()
    }
  }
}
