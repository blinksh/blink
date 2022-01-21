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
import Foundation

import ArgumentParser

import BlinkConfig
import SSH


typealias SSHClientConfigProviderMethod = (_ title: String) throws -> (String, SSHClientConfig)

class SSHClientControl {
  let connection: SSHClient
  let cancel: () -> Void

  init(_ conn: SSHClient, cancel: @escaping (() -> Void)) {
    self.connection = conn
    self.cancel = cancel
  }

  deinit {
    cancel()
  }
}

extension SSHClient {
  static func dial(_ host: String, withConfigProvider configProvider: @escaping SSHClientConfigProviderMethod) -> AnyPublisher<SSHClientControl, Error> {
    var thread: Thread!

    let hostName: String
    let config: SSHClientConfig
    do {
      (hostName, config) = try configProvider(host)
    } catch {
      return .fail(error: error)
    }

    let threadIsReady = Future<RunLoop, Error> { promise in
      thread = Thread {
        let timer = Timer(timeInterval: TimeInterval(1), repeats: true) { _ in
          //print("timer")
        }
        RunLoop.current.add(timer, forMode: .default)
        promise(.success(RunLoop.current))
        CFRunLoopRun()
        // Wrap it up
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
      }
      thread.start()
    }

    var proxyCancellable: AnyCancellable?
    var proxyConnectionControl: SSHClientControl? = nil
    var proxyStream: SSH.Stream? = nil
    let execProxyCommand: SSHClient.ExecProxyCommandCallback = { (command, sockIn, sockOut) in
      let output = DispatchOutputStream(stream: sockOut)
      let input = DispatchInputStream(stream: sockIn)

      // NOPE In this case we will have the client configuration + the configuration from the Command.
      // TODO This needs proper "shell" parsing
      guard let proxyCommand = try? ProxyCommand.parse(Array(command.components(separatedBy: " ")[1...])) else {
        print("Could not parse Proxy Command")
        return
      }
      guard let destination = proxyCommand.stdioHostAndPort else {
        print("No stdio on proxy tunnel found")
        return
      }

      let cancelProxy = { (error: Error?) in
        // This is necessary in order to propagate when the streams close.
        // Not clear yet where there is a copy of the socket.
        shutdown(sockIn, SHUT_RDWR)
        shutdown(sockOut, SHUT_RDWR)
        proxyConnectionControl?.cancel()
        // Not necessary, but for cleanliness in order to track the actions when debugging.
        // Otherwise, everything gets cleaned up once the whole session is detached.
        proxyStream?.cancel()
        proxyStream = nil
      }

      proxyCancellable =
        SSHClient.dial(proxyCommand.hostAlias, withConfigProvider: configProvider)
          .flatMap { connControl -> AnyPublisher<SSH.Stream, Error> in
            proxyConnectionControl = connControl
            connControl.connection.handleSessionException = { error in
              cancelProxy(error)
            }
            return connControl.connection.requestForward(to: destination.bindAddress,
                                                         port: Int32(destination.remotePort),
                                                         from: "blinkJumpHost",
                                                         localPort: 22)
          }
          .sink(
            receiveCompletion: { completion in
              switch completion {
                case .finished:
                  break
                case .failure(let error):
                  print(error)
              }
              // Self-retain until it is done.
              proxyCancellable = nil
            },
            receiveValue: { s in
              proxyStream = s
              s.connect(stdout: output, stdin: input)
              s.handleFailure = { error in
                cancelProxy(error)
              }
            }
          )
    }

    return AnyPublisher(threadIsReady.flatMap { runloop in
      Just(()).receive(on: runloop).flatMap {
        SSHClient
          .dial(hostName, with: config, withProxy: execProxyCommand)
          .map { conn -> SSHClient in

            return conn
          }
          .map {
            SSHClientControl($0, cancel: {
              let cfRunLoop = runloop.getCFRunLoop()
              CFRunLoopStop(cfRunLoop)
              proxyStream?.cancel()
              proxyStream = nil
              proxyConnectionControl?.cancel()
            })
          }
      }
    })
  }
}

struct ProxyCommand: ParsableCommand {
  // Login name
  @Option(
    name: [.customShort("l", allowingJoined: true)],
    help: .init(
      "Login name. This option can also be specified at the host",
      valueName: "login_name"
    )
  )
  var loginName: String?

  // Jumps
  @Option(
    name: [.customShort("J")],
    help: .init(
      "Jump Hosts in a comma separated list",
      valueName: "destination"
    )
  )
  var proxyJump: String?

  // Stdio forward
  @Option(name: [.customShort("W")],
          help: .init(
            "Forward stdio to the specified destination",
            valueName: "host:port"
          ),
          transform: { try BindAddressInfo($0) })
  var stdioHostAndPort: BindAddressInfo?

  // Connect to User at Host
  @Argument(help: "[user@]host[#port]")
  var userAtHost: String
  var hostAlias: String {
    get {
      let comps = userAtHost.components(separatedBy: "@")
      let hostAndPort = comps[comps.count - 1]
      let compsHost = hostAndPort.components(separatedBy: "#")
      return compsHost[0]
    }
  }
  var user: String? {
    get {
      // Login name preference over user@host
      if let user = loginName {
        return user
      }
      var comps = userAtHost.components(separatedBy: "@")
      if comps.count > 1 {
        comps.removeLast()
        return comps.joined(separator: "@")
      }
      return nil
    }
  }
  var port: UInt16? {
    get {
//      if let port = customPort {
//        return port
//      }
      let comps = userAtHost.components(separatedBy: "#")
      return comps.count > 1 ? UInt16(comps[1]) : nil
    }
  }
}
