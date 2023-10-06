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
  private typealias SSHConnection = AnyPublisher<SSH.SSHClient, Error>
  
  var outstream: Int32
  var instream: Int32
  var errstream: Int32
  let device: TermDevice
  var isTTY: Bool
  var stdout = OutputStream(file: thread_stdout)
  var stderr = OutputStream(file: thread_stderr)
  private var _mcp: MCPSession;

  var exitCode: Int32 = 0
  var cancellableBag: Set<AnyCancellable> = []
  let currentRunLoop = RunLoop.current
  var command: SSHCommand?
  var stream: SSH.Stream?
  var connection: SSH.SSHClient?
  var forwardTunnels: [PortForwardInfo] = []
  var remoteTunnels: [PortForwardInfo] = []
  var proxyThread: Thread?
  var socks: [OptionalBindAddressInfo] = []

  var outStream: DispatchOutputStream?
  var inStream: DispatchInputStream?
  var errStream: DispatchOutputStream?
  
  init(mcp: MCPSession) {
    _mcp = mcp;
    self.outstream = fileno(thread_stdout)
    self.instream = fileno(thread_stdin)
    self.errstream = fileno(thread_stderr)
    self.device = tty()
    self.isTTY = ios_isatty(self.instream) != 0
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
    do {
      cmd = try SSHCommand.parse(Array(argv[1...]))
      command = cmd
    } catch {
      let message = SSHCommand.message(for: error)
      print("\(message)", to: &stderr)
      return -1
    }
    
    let host: BKSSHHost
    let hostName: String
    let config: SSHClientConfig
    do {
      let commandHost = try cmd.bkSSHHost()
      host = try BKConfig().bkSSHHost(cmd.hostAlias, extending: commandHost)
      hostName = host.hostName ?? cmd.hostAlias
      config = try SSHClientConfigProvider.config(host: host, using: device)
    } catch {
      print("Configuration error - \(error)", to: &stderr)
      return -1
    }


    // The HostName is the defined by "host", or the one from the command.

    if cmd.printConfiguration {
      print("Configuration for \(cmd.hostAlias) as \(hostName)", to: &stdout)
      print("\(config.description)", to: &stdout)
      return 0
    }

    let connect: SSHConnection
    if let control = cmd.control {
      guard
        let conn = SSHPool.connection(for: hostName, with: config)
      else {
        print("No connection for \(cmd.hostAlias) to control", to: &stderr)
        return -1
      }
      switch control {
      // case .stop:
      //   SSHPool.deregister(runningCommand: cmd, on: conn)
      //   return 0
      case .forward:
        connect = .just(conn)
        break
      case .cancel:
        SSHPool.deregister(allTunnelsForConnection: conn)
        return 0
//      case .exit:
//        // This one would require to have a handle to the Session as well.
//        SSHPool.deregister(allFor: connection)
      default:
        print("Unknown control parameter \(control)", to: &stderr)
        return -1
      }
    } else {
      // Disable CM on -W, this way we attach it to the main connection only
      let useControlMaster = (cmd.stdioHostAndPort != nil) ? .no : (host.controlMaster ?? .no)
      
      connect = SSHPool.dial(
        hostName,
        with: config,
        withControlMaster: useControlMaster,
        withProxy: { [weak self] in
          guard let self = self
          else {
            return
          }
          self._mcp.setActiveSession()
          self.executeProxyCommand(command: $0, sockIn: $1, sockOut: $2)
        })
    }
    
    var environment: [String: String] = .init(minimumCapacity: host.sendEnv?.count ?? 0)
    
    host.sendEnv?.forEach({ env in
      // SKIP nil values
      if let value = getenv(env) {
        environment[env] = String(cString: value)
      }
    })

    connect.flatMap { conn -> SSHConnection in
      self.connection = conn

      if let banner = conn.issueBanner,
         !banner.isEmpty {
        print(banner, to: &self.stdout)
      }
      
      if cmd.startsSession {
        if let addr = conn.clientAddressIP() {
          print("Connected to \(addr)", to: &self.stdout)
        }

        // AgentForwardingPrompt
        var sendAgent = host.forwardAgent ?? false

        if let bkHost = BKHosts.withHost(cmd.hostAlias),
           let agent = conn.agent {
          if self.loadAgentForwardKeys(bkHost: bkHost, agent: agent) {
            sendAgent = true
          }
        }

        return self.startInteractiveSessions(conn,
                                             command: host.remoteCommand,
                                             requestTTY: host.requestTty ?? .auto,
                                             withEnvVars: environment,
                                             sendAgent: sendAgent)
      }
      return .just(conn)
    }
    .flatMap { self.startStdioTunnel($0, command: cmd) }
    // TODO In order to support ExitOnForwardFailure, we will have to become a bit smarter here.
    // ExitOnForwardFailure only closes if the bind for -L/-R fails
    // TODO Note, we are not merging localForward on host and cmd yet. There can also be -o.
    .flatMap { self.startForwardTunnels( (host.localForward ?? []), on: $0, exitOnFailure: host.exitOnForwardFailure ?? false) }
    .flatMap { self.startRemoteTunnels( (host.remoteForward ?? []), on: $0, exitOnFailure: host.exitOnForwardFailure ?? false) }
    .flatMap { self.startDynamicForwarding( (host.dynamicForward ?? []), on: $0, exitOnFailure: host.exitOnForwardFailure ?? false) }
    .sink(receiveCompletion: { completion in
      switch completion {
      case .failure(let error):
        print("Error connecting to \(cmd.hostAlias). \(error)", to: &self.stderr)
        self.exitCode = -1
        self.kill()
      default:
        // Connection OK
        break
      }
    }, receiveValue: { conn in
      if !cmd.blocks {
        self.kill()
      }
    })
    .store(in: &cancellableBag)

    awaitRunLoop(currentRunLoop)

    stream?.cancel()
    outStream?.close()
    inStream?.close()
    errStream?.close()
    // Dispatch streams need a cycle to close.
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

    // Need to get rid of the stream because the channel needs a cycle to be closed.
    self.stream = nil

    if let conn = self.connection, cmd.blocks {
      if cmd.startsSession { SSHPool.deregister(shellOn: conn) }
      forwardTunnels.forEach { SSHPool.deregister(localForward:  $0, on: conn) }
      remoteTunnels.forEach  { SSHPool.deregister(remoteForward: $0, on: conn) }
      socks.forEach { SSHPool.deregister(socksBindAddress: $0, on: conn) }
    }
    
    return exitCode
  }

  private func executeProxyCommand(command: String, sockIn: Int32, sockOut: Int32) {
    /* Prepare /dev/null socket for the stderr redirection */
    let devnull = open("/dev/null", O_WRONLY);
    if devnull == -1 {
      ios_exit(1)
    }

    /* redirect in and out to stdin, stdout */
    ios_dup2(sockIn,  STDIN_FILENO)
    ios_dup2(sockOut, STDOUT_FILENO)
    ios_dup2(devnull, STDERR_FILENO)

    ios_system(command);
  }

  private func startInteractiveSessions(_ conn: SSH.SSHClient,
                                        command: String?,
                                        requestTTY: TTYBool,
                                        withEnvVars envVars: [String:String],
                                        sendAgent: Bool) -> SSHConnection {
    let rows = Int32(self.device.rows)
    let cols = Int32(self.device.cols)
    var pty: SSH.SSHClient.PTY? = nil
    if (requestTTY != .no) && 
       ( 
         (requestTTY == .force) ||
         // always request a TTY when standard input is a TTY
         ((requestTTY == .yes) && self.isTTY) ||
         // request a TTY when opening a login session
         ((requestTTY == .auto) && command == nil)
       ) {       
      pty = SSH.SSHClient.PTY(rows: rows, columns: cols)
      self.device.rawMode = true
    }

    // TERM is explicitely added
    var envVars = envVars
    envVars["TERM"] = String(cString: getenv("TERM"))

    let session: AnyPublisher<SSH.Stream, Error>
    if let command = command {
      session = conn.requestExec(command: command, withPTY: pty,
                                 withEnvVars: envVars,
                                 withAgentForwarding: sendAgent)      
    } else {
      session = conn.requestInteractiveShell(withPTY: pty,
                                             withEnvVars: envVars,
                                             withAgentForwarding: sendAgent)
    }

    return session.tryMap { s in
      let outs = DispatchOutputStream(stream: self.outstream)
      let ins = DispatchInputStream(stream: self.instream)
      let errs = DispatchOutputStream(stream: self.errstream)

      s.handleCompletion = {
        // Once finished, exit.
        self.kill()
        return
      }
      s.handleFailure = { error in
        self.exitCode = -1
        print("Interactive Shell error. \(error)", to: &self.stderr)
        self.kill()
        return
      }

      s.connect(stdout: outs, stdin: ins, stderr: errs)
      self.outStream = outs
      self.inStream = ins
      self.errStream = errs
      SSHPool.register(shellOn: conn)
      self.stream = s
      return conn
    }.eraseToAnyPublisher()
  }

  private func startStdioTunnel(_ conn: SSH.SSHClient, command: SSHCommand) -> SSHConnection {
    guard let tunnel = command.stdioHostAndPort else {
      return .just(conn)
    }
    
    return conn.requestForward(to: tunnel.bindAddress, port: Int32(tunnel.port),
                          // Just informative.
                          from: "stdio", localPort: 22)
      .tryMap { s in
        SSHPool.register(stdioStream: s, runningCommand: command, on: conn)
        let outStream = DispatchOutputStream(stream: dup(self.outstream))
        let inStream = DispatchInputStream(stream: dup(self.instream))
        s.connect(stdout: outStream, stdin: inStream)

        s.handleCompletion = {
          print("Stdio Tunnel completed")
          SSHPool.deregister(allTunnelsForConnection: conn)
          self.kill()
          //SSHPool.deregister(runningCommand: command, on: conn)
        }
        s.handleFailure = { error in
          print("Stdio Tunnel completed")
          SSHPool.deregister(allTunnelsForConnection: conn)
          self.kill()
          //SSHPool.deregister(runningCommand: command, on: conn)
        }
        
        return conn
      }.eraseToAnyPublisher()
  }

  private func startForwardTunnels(_ tunnels: [PortForwardInfo], 
                                   on conn: SSH.SSHClient,
                                   exitOnFailure: Bool) -> SSHConnection {
    let tunnels = tunnels.filter { !SSHPool.contains(localForward: $0, on: conn) }
    if tunnels.isEmpty {
      return .just(conn)
    }
    
    return tunnels.publisher
      .flatMap(maxPublishers: .max(1)) { tunnel -> AnyPublisher<Void, Error> in
        let lis = SSHPortForwardListener(on: tunnel.localPort, toDestination: tunnel.bindAddress, on: tunnel.remotePort, using: conn)
        
        // Await for Listener to bind and be ready.
        return lis.ready().map {
          SSHPool.register(lis, portForwardInfo: tunnel, on: conn)
          self.forwardTunnels.append(tunnel)
        }
        // In case of failure, exit report and continue.
        .tryCatch { error -> AnyPublisher<Void, Error> in
          if exitOnFailure {
            throw error
          }
          
          print("\(error)", to: &self.stderr)
          return .just(Void())
        } 
        .eraseToAnyPublisher()
      }
      .last()
      .map { conn }
      .eraseToAnyPublisher()
  }

  private func startRemoteTunnels(_ tunnels: [PortForwardInfo],
                                  on conn: SSH.SSHClient, 
                                  exitOnFailure: Bool) -> SSHConnection {
    let tunnels = tunnels.filter { !SSHPool.contains(remoteForward: $0, on: conn) }
    if tunnels.isEmpty {
      return .just(conn)
    }

    return tunnels.publisher
      .flatMap(maxPublishers: .max(1)) { tunnel -> AnyPublisher<Void, Error> in
        let client: SSHPortForwardClient
        client = SSHPortForwardClient(forward: tunnel.bindAddress,
                                      onPort: tunnel.remotePort,
                                      toRemotePort: tunnel.localPort,
                                      using: conn)
        
        
        // Await for Client to be setup and ready.
        return client.ready().map {
          self.remoteTunnels.append(tunnel)
          // Mark to dashboard
          SSHPool.register(client, portForwardInfo: tunnel, on: conn)
        }
        .tryCatch { error -> AnyPublisher<Void, Error> in
          if exitOnFailure {
            throw error
          }
          print("\(error)", to: &self.stderr)
          return .just(Void())
        }
        .eraseToAnyPublisher()
      }
      .last()
      .map {
        conn
      }
      .eraseToAnyPublisher()
  }

  private func startDynamicForwarding(_ bindAddresses: [OptionalBindAddressInfo], on conn: SSH.SSHClient, exitOnFailure: Bool) -> SSHConnection {
    let bindAddresses = bindAddresses.filter { !SSHPool.contains(socksBindAddress: $0, on: conn) }
    if bindAddresses.isEmpty {
      return .just(conn)
    }

    return bindAddresses.publisher
      .flatMap(maxPublishers: .max(1)) { bindAddress -> AnyPublisher<Void, Error> in
        do {
          let server = try SOCKSServer(bindAddress.port, proxy: conn)
          SSHPool.register(server, bindAddressInfo: bindAddress, on: conn)
          self.socks.append(bindAddress)
        } catch {
          return .fail(error: error)
        }
        return .just(Void())
      }
      .last()
      .map { conn }
      .eraseToAnyPublisher()    
  }

  private func loadAgentForwardKeys(bkHost: BKHosts, agent: SSHAgent) -> Bool {
    var constraints: [SSHAgentConstraint]? = nil
    let agentForwardPrompt = BKAgentForward(UInt32(bkHost.agentForwardPrompt?.intValue ?? 0))

    if agentForwardPrompt == BKAgentForwardConfirm {
      constraints = [SSHAgentUserPrompt()]
    } else if agentForwardPrompt == BKAgentForwardYes {
      constraints = []
    } else {
      return false
    }

    if constraints != nil {
      let _allIdentities = BKPubKey.all()
      for keyName in bkHost.agentForwardKeys {
        if let signer = _allIdentities.signerWithID(keyName) {
          agent.loadKey(signer, aka: keyName, constraints: constraints)
        }
      }
    }

    return true
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
