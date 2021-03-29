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
import ios_system

@_cdecl("blink_ssh_main")
public func blink_ssh_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkSSH(mcp: session)
  return cmd.start(argc, argv: argv.args(count: argc))
}

@objc public class BlinkSSH: NSObject {
  var outstream: Int32
  var instream: Int32
  let device: TermDevice
  var isTTY: Bool
  var stdout = StdoutOutputStream()
  var stderr = StderrOutputStream()
  private var _mcp: MCPSession;

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

  var outStream: DispatchOutputStream?
  var inStream: DispatchInputStream?
  
  init(mcp: MCPSession) {
    _mcp = mcp;
    self.outstream = fileno(thread_stdout)
    self.instream = fileno(thread_stdin)
    self.device = tty()
    self.isTTY = ios_isatty(self.instream) != 0
    self.currentRunLoop = RunLoop.current
    super.init()
  }

  @objc public func start(_ argc: Int32, argv: [String]) -> Int32 {
    _mcp.registerSSHClient(self)
    let originalRawMode = device.rawMode
    defer {
      _mcp.unregisterSSHClient(self)
      device.rawMode = originalRawMode
    }

    let cmd: SSHCommand
    let options: ConfigFileOptions
    do {
      cmd = try SSHCommand.parse(Array(argv[1...]))
      command = cmd
      options = try cmd.connectionOptions.get()
    } catch {
      let message = SSHCommand.message(for: error)
      print("\(message)", to: &stderr)
      return -1
    }

    let (hostName, config) = SSHClientConfigProvider.config(command: cmd, using: device)
    if cmd.printConfiguration {
      print("Configuration for \(cmd.host) as \(hostName)", to: &stdout)
      print("\(config.description)", to: &stdout)
      return 0
    }


    if let control = cmd.control {
      guard
        let conn = SSHPool.connection(for: hostName, with: config)
      else {
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

    SSHPool.dial(
      hostName,
      with: config,
      connectionOptions: options,
      withProxy: { [weak self] in
        guard let self = self
        else {
          return
        }
        self._mcp.setActiveSession()
        self.executeProxyCommand(command: $0, sockIn: $1, sockOut: $2)
      })
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

        // Print connected address to pickup by mosh command
        if let addr = conn.clientAddressIP() {
          print("Connected to \(addr)", to: &self.stdout)
        }
        
        if cmd.startsSession {
          self.startInteractiveSessions(conn, command: cmd)
        }
        // A tunnel may still be running in the background if we wish, like this one. The thread should only
        // not block if we have a specific flag (like just starting a tunnel, control command or the specific flag).
        self.startStdioTunnel(conn, command: cmd)
        // NOTE Cannot implement ExitOnForwardFailure with this flow.
        self.startForwardTunnels(conn, command: cmd)
        self.startReverseTunnels(conn, command: cmd)

        
      }).store(in: &cancellableBag)

    if cmd.blocks {
      await(runLoop: currentRunLoop)
      print("Thread woke")
    }

    stream?.cancel()
    outStream?.close()
    inStream?.close()
    // Dispatch streams need a cycle to close.
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

    // Need to get rid of the stream because the channel needs a cycle to be closed.
    self.stream = nil
    // The channel is responsibility of the other thread, so this runloop is not need atm.
    //RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    if let conn = self.connection, cmd.stdioHostAndPort == nil {
      SSHPool.deregister(runningCommand: cmd, on: conn)
    }

    return exitCode
  }

  func executeProxyCommand(command: String, sockIn: Int32, sockOut: Int32) {
    // Tried to run it through objc, but no luck.
    //__thread_ssh_execute_command(command, sockIn, sockOut)
    /* Prepare /dev/null socket for the stderr redirection */
    let devnull = open("/dev/null", O_WRONLY);
    if devnull == -1 {
      ios_exit(1)
    }

    /* redirect in and out to stdin, stdout */
    ios_dup2(sockIn,  STDIN_FILENO)
    ios_dup2(sockOut, STDOUT_FILENO)
    ios_dup2(devnull, STDERR_FILENO)

    var cmd = command
    cmd.removeAll(where: { $0 == "[" || $0 == "]" })
    ios_system(cmd);
  }

  func startInteractiveSessions(_ conn: SSH.SSHClient, command: SSHCommand) {
    let rows = Int32(self.device.rows)
    let cols = Int32(self.device.cols)
    var pty: SSH.SSHClient.PTY? = nil
    if command.forceTTY || (self.isTTY && !command.disableTTY && command.command.isEmpty) {
      pty = SSH.SSHClient.PTY(rows: rows, columns: cols)
      self.device.rawMode = true
    }
    
    let session: AnyPublisher<SSH.Stream, Error>
    
    let opts = try? command.connectionOptions.get()
    
    if command.command.isEmpty {
      session = conn.requestInteractiveShell(withPTY: pty,
                                             withEnvVars: opts?.sendEnv ?? [:],
                                             withAgentForwarding: command.agentForward)
    } else {
      let exec = command.command.joined(separator: " ")
      session = conn.requestExec(command: exec, withPTY: pty,
                                 withEnvVars: opts?.sendEnv ?? [:],
                                 withAgentForwarding: command.agentForward)
    }

    session
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
        let outs = DispatchOutputStream(stream: self.outstream)
        let ins = DispatchInputStream(stream: self.instream)

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

        s.connect(stdout: outs, stdin: ins)
        self.outStream = outs
        self.inStream = ins
        SSHPool.register(shellOn: conn)
        self.stream = s
      }).store(in: &cancellableBag)
  }

  func startStdioTunnel(_ conn: SSH.SSHClient, command: SSHCommand) {
    if let tunnel = command.stdioHostAndPort {
      conn.requestForward(to: tunnel.bindAddress, port: Int32(tunnel.remotePort),
                          // Just informative.
                          from: "stdio", localPort: 22)
        .sink(receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Error creating stdio tunnel. \(error)", to: &self.stderr)
            self.exitCode = -1
            self.kill()
          }
        },
        receiveValue: { s in
          SSHPool.register(stdioStream: s, runningCommand: command, on: conn)
          let outStream = DispatchOutputStream(stream: dup(self.outstream))
          let inStream = DispatchInputStream(stream: dup(self.instream))
          s.connect(stdout: outStream, stdin: inStream)

          s.handleCompletion = {
            SSHPool.deregister(runningCommand: command, on: conn)
          }
          s.handleFailure = { error in
            SSHPool.deregister(runningCommand: command, on: conn)
          }
          // The tunnel is already stored, so we can close the process.
          self.kill()
        }).store(in: &cancellableBag)
    }
  }

  func startForwardTunnels(_ conn: SSH.SSHClient, command: SSHCommand) {
    if let tunnel = command.localPortForward {
      let lis = SSHPortForwardListener(on: tunnel.localPort, toDestination: tunnel.bindAddress, on: tunnel.remotePort, using: conn)
      //tunnels.append(lis)
      // TODO Only register with the pool once the event is 'ready'.
      //SSHPool.register(lis, runningCommand: command, on: conn)

      lis.connect().sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          print("Tunnel finished")
        case .failure(let error):
          print("Error starting tunnel. \(error)", to: &self.stderr)
        }
      }, receiveValue: { event in
        print("Tunnel received \(event)")
        if case .ready = event {
          SSHPool.register(lis, runningCommand: command, on: conn)
        }
      }).store(in: &cancellableBag)
    }
  }

  func startReverseTunnels(_ conn: SSH.SSHClient, command: SSHCommand) {
    if let tunnel = command.reversePortForward {
      let client: SSHPortForwardClient
      client = SSHPortForwardClient(forward: tunnel.bindAddress,
                                    onPort: tunnel.remotePort,
                                    toRemotePort: tunnel.localPort,
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
          SSHPool.register(client, runningCommand: command, on: conn)
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
    c = stream?
      .resizePty(rows: Int32(device.rows), columns: Int32(device.cols))
      .sink(receiveCompletion: { completion in
        if case .failure(let error) = completion {
          print(error)
        }
        c?.cancel()
      }, receiveValue: {})
  }

  @objc public func kill() {
    // Cancelling here makes sure the flows are cancelled.
    // Trying to do it at the runloop has the issue that flows may continue running.
    print("Kill received")
    cancellableBag = []

    awake(runLoop: currentRunLoop)
  }

  deinit {
    print("OUT")
  }
}
