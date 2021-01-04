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
import SSH
import Combine
import Dispatch


@_cdecl("blink_ssh_main")
func blink_ssh_main(argc: Int32, argv: Argv) -> Int32 {
  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkSSH()
  session.registerSSHClient(cmd)
  let rc = cmd.start(argc, argv: argv.args(count: argc))
  session.unregisterSSHClient(cmd)

  return rc
}

@objc public class BlinkSSH: NSObject {
  let outstream: Int32
  let instream: Int32
  let device: TermDevice
  var stderr = StderrOutputStream()

  var exitCode: Int32 = 0
  var cancellableBag: Set<AnyCancellable> = []
  let currentRunLoop: RunLoop
  var command: SSHCommand?
  var stream: SSH.Stream?
  var connection: SSH.SSHClient?
  var tunnels: [SSHPortForwardListener] = []
  var tunnelStream: SSH.Stream?
  var reverseTunnels: [SSHPortForwardClient] = []
  var proxyThread: Thread?

  override init() {
    // Duplicate before transforming them, because ios_sytem
    // still needs the original streams.
    self.outstream = fileno(thread_stdout)
    self.instream = fileno(thread_stdin)
    self.device = tty()
    self.currentRunLoop = RunLoop.current
  }

  @objc public func start(_ argc: Int32, argv: [String]) -> Int32 {
    let originalRawMode = device.rawMode

    let cmd: SSHCommand
    let options: ConfigFileOptions
    do {
      cmd = try SSHCommand.parse(Array(argv[1...]))
      options = try cmd.connectionOptions.get()

      command = cmd
    } catch {
      let message = SSHCommand.message(for: error)
      print("\(message)", to: &stderr)
      return -1
    }

    let config = SSHClientConfigProvider.config(command: cmd, using: device)

    if let control = cmd.control {
      guard let conn = SSHPool.connection(for: cmd.host, with: config) else {
        print("No connection for \(cmd.host) to control", to: &stderr)
        return -1
      }
      switch control {
      case .stop:
        SSHPool.deregister(runningCommand: cmd, on: conn)
//      case .cancel:
//        SSHPool.deregister(allTunnelsFor: connection)
//      case .exit:
//        // This one would require to have a handle to the Session as well.
//        SSHPool.deregister(allFor: connection)
      default:
        print("Unknown control parameter \(control)", to: &stderr)
        return -1
      }
      return 0
    }

    SSHPool.dial(cmd.host, with: config, connectionOptions: options)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print("Error connecting to \(cmd.host). \(error)", to: &self.stderr)
          self.kill()
        default:
          // Connection OK
          break
        }
      }, receiveValue: { conn in
        self.connection = conn

        self.startForwardTunnels(conn, command: cmd)
        self.startReverseTunnels(conn, command: cmd)

        if cmd.startsSession {
          self.startInteractiveSessions(conn, command: cmd)
        }
      }).store(in: &cancellableBag)

    if cmd.startsSession {
      await(runLoop: currentRunLoop)

      // NOTE First deallocate the stream, so it can be deinited before
      // the thread is descheduled.
      stream?.cancel()
      self.stream = nil
      self.cancellableBag = []

      if let conn = self.connection {
        SSHPool.deregister(runningCommand: cmd, on: conn)
      }
    }

    // Deregister the command
    // Do not get a reference here.
    
    device.rawMode = originalRawMode
    return exitCode
  }

  func executeProxyCommand(command: String, sockIn: Int32, sockOut: Int32) {
    // If this is a jump, we process it here.
    // Otherwise we execute another command through the shell.

    // TODO Possible issues with the command, as components may not be enough.

    // TODO Thread per connection should be handled by the pool,
    // but for now we will dump it here.
    proxyThread = Thread {
      let args = command.dropFirst("ssh ".count)
      guard let cmd = try? SSHCommand.parse(args.components(separatedBy: " ")) else {
        print("Unrecognized ProxyCommand arguments", to: &self.stderr)
        return
      }

      var connection: SSH.SSHClient?
      var proxyStream: SSH.Stream?

      let config = SSHClientConfigProvider.config(command: cmd, using: self.device)

      let c = SSHClient.dial(cmd.host, with: config)
        .flatMap { conn -> AnyPublisher<SSH.Stream, Error> in
          // connection = conn
          return conn.requestForward(to: cmd.host, port: Int32(cmd.port ?? 22),
                                     // TODO Just informative, should make optional.
                                     from: "localhost", localPort: 22)
        }.sink(receiveCompletion: { end in
          switch end {
          case .failure(let error):
            close(sockIn)
            close(sockOut)
            print("Failed to execute ProxyCommand", to: &self.stderr)
          default:
            break
          }
        }, receiveValue: { s in
          let output = DispatchOutputStream(stream: sockOut)
          let input = DispatchInputStream(stream: sockIn)
          proxyStream = s
          s.connect(stdout: output, stdin: input)
          // TODO Capture Completion
        })

      CFRunLoopRun()
    }

    proxyThread?.start()
  }

  func startInteractiveSessions(_ conn: SSH.SSHClient, command: SSHCommand) {
    let rows = self.device.rows
    let cols = self.device.cols

    conn.requestInteractiveShell(rows: Int32(rows), columns: Int32(cols))
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print(error)
          self.kill()
          return
        default:
          // Interactive OK
          break
        }
      }, receiveValue: { s in
        self.device.rawMode = true
        s.handleCompletion = {
          // Once finished, exit.
          self.kill()
          return
        }
        s.handleFailure = { error in
          self.exitCode = -1
          print("Error starting Interactive Shell. \(error)", to: &self.stderr)
          self.kill()
          return
        }
        
        let outStream = DispatchOutputStream(stream: dup(self.outstream))
        let inStream = DispatchInputStream(stream: dup(self.instream))
        s.connect(stdout: outStream, stdin: inStream)
        
        SSHPool.register(shellOn: conn)
        self.stream = s
      }).store(in: &cancellableBag)
  }

  func startForwardTunnels(_ conn: SSH.SSHClient, command: SSHCommand) {
    if let tunnel = command.localPortForward {
      let lis = SSHPortForwardListener(on: tunnel.localPort, toDestination: tunnel.bindAddress, on: tunnel.remotePort, using: conn)
      //tunnels.append(lis)
      // TODO Only register with the pool once the event is 'ready'.
      SSHPool.register(lis, runningCommand: command, on: conn)

      lis.connect().sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          print("Tunnel finished")
        case .failure(let error):
          print("Error starting tunnel. \(error)", to: &self.stderr)
        }
      }, receiveValue: { event in
        print("Tunnel received \(event)")
      }).store(in: &cancellableBag)
    }
  }

  func startReverseTunnels(_ conn: SSH.SSHClient, command: SSHCommand) {
    if let tunnel = command.reversePortForward {
      let client: SSHPortForwardClient
      client = SSHPortForwardClient(forward: tunnel.bindAddress,
                                    onPort: tunnel.localPort,
                                    toRemotePort: tunnel.remotePort,
                                    using: conn)
      reverseTunnels.append(client)

      client.connect().sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          print("Reverse tunnel finished")
        case .failure(let error):
          print("Error starting reverse tunnel. \(error)", to: &self.stderr)
        }
      }, receiveValue: { event in
        print("Reverse tunnel event \(event)")
        switch event {
        case .ready:
          // Mark to dashboard
          break
        case .error(let error):
          // Capture on dashboard.
          print("Error on reverse tunnel \(error)")
        default:
          break
        }
      }).store(in: &self.cancellableBag)
    }
  }

  @objc public func sigwinch() {
    var c: AnyCancellable?
    c = stream?.resizePty(rows: Int32(device.rows), columns: Int32(device.cols))
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          print(error)
        default:
          c = nil
        }
      }, receiveValue: {})
  }

  @objc public func kill() {
    awake(runLoop: currentRunLoop)
  }
  
  deinit {
    print("OUT")
  }
}
