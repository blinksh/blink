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

    let threadIsReady = Deferred {
      Future<RunLoop, Error> { promise in
        thread = Thread {
          print("THREAD STARTED!!")
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
      print("THREAD IS READY")
      return Just(()).receive(on: runloop).flatMap {
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

extension SSHClient {
  static func dialInThread(_ host: String, withConfigProvider configProvider: @escaping SSHClientConfigProviderMethod) -> AnyPublisher<SSH.SSHClient, Error> {
    let hostName: String
    let config: SSHClientConfig
    do {
      (hostName, config) = try configProvider(host)
    } catch {
      return .fail(error: error)
    }

    var proxyCancellable: AnyCancellable?
    var proxyStream: SSH.Stream? = nil
    let execProxyCommand: SSHClient.ExecProxyCommandCallback = { (command, sockIn, sockOut) in
      let output = DispatchOutputStream(stream: sockOut)
      let input = DispatchInputStream(stream: sockIn)

      let cancelProxy = { (error: Error?) in
        // This is necessary in order to propagate when the streams close.
        shutdown(sockIn, SHUT_RDWR)
        shutdown(sockOut, SHUT_RDWR)

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
        SSH.SSHClient.dialInThread(proxyCommand.hostAlias, withConfigProvider: configProvider)
          .flatMap { conn -> AnyPublisher<SSH.Stream, Error> in
            // proxyConnectionControl = connControl
            conn.handleSessionException = { error in
              cancelProxy(error)
            }
            return conn.requestForward(to: destination.bindAddress,
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
              // The proxyStream is self-retaining itself for cancellation.
              s.handleFailure = { error in
                cancelProxy(error)
              }
              s.handleCompletion = { cancelProxy(nil) }
            }
          )
    }

    let pb = PassthroughSubject<SSH.SSHClient, Error>()
    var dial: AnyCancellable?

    let t = Thread {
      let runLoop = RunLoop.current

      dial = SSH.SSHClient.dial(hostName, with: config, withProxy: execProxyCommand)
        .print("SSHClient dialInThread")
        .mapError { error in
          if let sshError = error as? SSHError, case .authFailed = sshError {
            return NSFileProviderError(.notAuthenticated, userInfo: [NSLocalizedFailureReasonErrorKey: sshError.description])
          } else {
            return NSFileProviderError(.serverUnreachable, userInfo: [NSLocalizedFailureReasonErrorKey: error.localizedDescription])
          }
        }
        .sink(
          receiveCompletion: { completion in
            pb.send(completion: completion)
          },
          receiveValue: { conn in
            pb.send(conn)
          })

      SSH.SSHClient.run(withTimer: true)
      print("SSHClient dialInThread Out")
    }

    return Just(t)
      .flatMap { t in
        t.start()
        return pb
      }
      .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .eraseToAnyPublisher()
  }
}


fileprivate struct ProxyCommand {
  struct Error: Swift.Error {
    let description: String
  }

  let jumpHost: String?
  let stdioForward: BindAddressInfo
  let hostAlias: String

  // The command we receive is pre-fabricated by LibSSH, so we capture
  // looped JumpHosts, StdioForward and HostAlias in that order.
  // ssh -J l,l -W [127.0.0.1]:22 l
  private let pattern =
    #"ssh (-J (?<JumpHost>.*) )?(-W (?<StdioForward>.*)) (?<HostAlias>.*)"#
  init(_ command: String) throws {
    let regex = try NSRegularExpression(pattern: pattern)
    let matchRange = NSRange(command.startIndex..., in: command)

    guard
      let match = regex.firstMatch(in: command,
                                   range: matchRange)
    else {
      throw Error(description: "Invalid ProxyCommand \(command)")
    }

    if let r = Range(match.range(withName: "JumpHost"), in: command) {
      self.jumpHost = String(command[r])
    } else {
      self.jumpHost = nil
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

var logCancellables = Set<AnyCancellable>()

enum SSHClientConfigProvider {

  static func config(host title: String) throws -> (String, SSHClientConfig) {

    // NOTE This is just regular config initialization. Usually happens on AppDelegate, but the
    // FileProvider doesn't get another chance.
    BKHosts.loadHosts()
    BKPubKey.loadIDS()

    let bkConfig = try BKConfig()
    let agent = SSHAgent()
    let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]

    let host = try bkConfig.bkSSHHost(title)

    if let signers = bkConfig.signer(forHost: host) {
      signers.forEach { (signer, name) in
        agent.loadKey(signer, aka: name, constraints: consts)
      }
    } else {
      for (signer, name) in bkConfig.defaultSigners() {
        agent.loadKey(signer, aka: name, constraints: consts)
      }
    }

    var availableAuthMethods: [AuthMethod] = [AuthAgent(agent)]
    if let password = host.password, !password.isEmpty {
      availableAuthMethods.append(AuthPassword(with: password))
    }

    let log = BlinkLogger("SSH")
    let logger = PassthroughSubject<String, Never>()
    logger.sink {
      log.send($0)

    }.store(in: &logCancellables)


    return (host.hostName ?? title,
            host.sshClientConfig(authMethods: availableAuthMethods,
                                 agent: agent,
                                 logger: logger)
    )
  }
}
