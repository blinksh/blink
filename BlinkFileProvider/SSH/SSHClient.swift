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

      guard let proxyCommand = try? ProxyCommand(command) else {
        print("Could not parse Proxy Command")
        cancelProxy(nil)
        return
      }
      
      let destination = proxyCommand.stdioForward

      proxyCancellable =
        SSHClient.dial(proxyCommand.hostAlias, withConfigProvider: configProvider)
          .flatMap { connControl -> AnyPublisher<SSH.Stream, Error> in
            proxyConnectionControl = connControl
            connControl.connection.handleSessionException = { error in
              cancelProxy(error)
            }
            return connControl.connection.requestForward(to: destination.bindAddress,
                                                         port: Int32(destination.port),
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

fileprivate struct ProxyCommand {
  struct Error: Swift.Error {
    let description: String
  }
  
  let stdioForward: BindAddressInfo
  let hostAlias: String
  
  // The command we receive is pre-fabricated by LibSSH, so we just parse.
  // ssh -W [127.0.0.1]:22 l
  private let pattern =
    #"ssh (-W (?<StdioForward>.*)) (?<HostAlias>.*)"#
  init(_ command: String) throws {
    let regex = try NSRegularExpression(pattern: pattern)
    let matchRange = NSRange(command.startIndex..., in: command)

    guard
      let match = regex.firstMatch(in: command,
                                   range: matchRange)
    else {
      throw Error(description: "Invalid ProxyCommand \(command)")
    }
    
    if let r = Range(match.range(withName: "StdioForward"), in: command) {
      self.stdioForward = try BindAddressInfo(String(command[r]))
    } else {
      throw Error(description: "Missing forward. \(command)")
    }
    
    if let r = Range(match.range(withName: "HostAlias"), in: command) {
      self.hostAlias = String(command[r])
    } else {
      throw Error(description: "Missing forward. \(command)")
    }
  }
}
