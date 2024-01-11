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
import Dispatch

import SSH
import ios_system

// TODO Enable mosh2 as the old mosh session. Will have to be hard-coded on MCP.

// @_cdecl("blink_mosh_main")
// public func blink_mosh_main(argc: Int32, argv: Argv) -> Int32 {
//   setvbuf(thread_stdin, nil, _IONBF, 0)
//   setvbuf(thread_stdout, nil, _IONBF, 0)
//   setvbuf(thread_stderr, nil, _IONBF, 0)

//   let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
//   // TODO How about register and deregister here?
//   let cmd = BlinkMosh()
//   return cmd.start(argc, argv: argv.args(count: argc))
// }

enum MoshError: Error {
  case NoBinaryAvailable
  case NoBinaryExecFlag
  case NoChecksumMatch
  case UserCancelled
  case NoMoshServerArgs
  case NoRemoteServerIP
  case AddressInfo(String)
  case StartMoshServerError(String)
}

@objc public class BlinkMosh: Session {
  var exitCode: Int32 = 0
  var sshCancellable: AnyCancellable? = nil
  var currentRunLoop: RunLoop!
  var stdin: InputStream!
  var stdout: OutputStream!
  var stderr: OutputStream!
  private var initialMoshParams: MoshParams? = nil
  private let mcpSession: MCPSession
  private var suspendSemaphore: DispatchSemaphore? = nil
  private let escapeKey: String
  private var logger: MoshLogger! = nil
  var isRunloopRunning = false

  let stateCallback: mosh_state_callback = { (context, buffer, size) in
    guard let buffer = buffer, let context = context else {
      return
    }
    let data = Data(bytes: buffer, count: size)
    let session = Unmanaged<BlinkMosh>.fromOpaque(context).takeUnretainedValue()
    session.onStateEncoded(data)
  }

  @objc init!(mcpSession: MCPSession, device: TermDevice!, andParams params: SessionParams!) {
    if let escapeKey = ProcessInfo.processInfo.environment["MOSH_ESCAPE_KEY"],
       escapeKey.count == 1 {
      self.escapeKey = escapeKey
    } else {
      self.escapeKey = "\u{1e}"
    }
    self.mcpSession = mcpSession

    super.init(device: device, andParams: params)

    self.stdin = InputStream(file: stream.in)
    self.stdout = OutputStream(file: stream.out)
    self.stderr = OutputStream(file: stream.err)
  }

  @objc public override func main(_ argc: Int32, argv: Argv) -> Int32 {
    mcpSession.setActiveSession()
    self.currentRunLoop = RunLoop.current
    // In ObjC, sessionParams is a covariable for MoshParams.
    // In Swift we need to cast.
    if let initialMoshParams = self.sessionParams as? MoshParams,
       let _ = initialMoshParams.encodedState {
      return moshMain(initialMoshParams)
    } else {
      let command: MoshCommand
      do {
        command = try MoshCommand.parse(Array(argv.args(count: argc)[1...]))
      } catch {
        let message = MoshCommand.message(for: error)
        return die(message: message)
      }

      self.logger = MoshLogger(output: self.stderr, logLevel: command.verbose ? .info : .error)
      
      let moshParams: MoshParams
      do {
        moshParams = try startMoshServer(using: command)
        self.copyToSession(moshParams: moshParams)
      } catch {
        return die(message: "\(error)")
      }

      return moshMain(moshParams)
    }
  }

  func startMoshServer(using command: MoshCommand) throws -> MoshParams {
    let host: BKSSHHost
    let config: SSHClientConfig
    let hostName: String
    let log = logger.log("startMoshServer")

    host = try BKConfig().bkSSHHost(command.hostAlias, extending: command.bkSSHHost())
    hostName = host.hostName ?? command.hostAlias
    config = try SSHClientConfigProvider.config(host: host, using: device)

    let moshClientParams = MoshClientParams(extending: command)
    let moshServerParams: MoshServerParams
    if let customKey = command.customKey {
      guard let customUDPPort = moshClientParams.customUDPPort else {
        throw MoshError.StartMoshServerError("If MOSH_KEY is set, port is required. (-p)")
      }

      // Resolved as part of the host info or explicit on params.
      let remoteIP = hostName
      moshServerParams = MoshServerParams(key: customKey, udpPort: customUDPPort, remoteIP: remoteIP)
      log.info("Manual Mosh server bootstrapped with params \(moshServerParams)")
    } else {
      let moshServerStartupArgs = getMoshServerStartupArgs(udpPort: moshClientParams.customUDPPort,
                                                           colors: nil,
                                                           exec: moshClientParams.remoteExecCommand)

      let sequence: [MoshBootstrap]
      // NOTE Users may want a way to disable or make installation explicit. Right now, we offer it by default.
      if moshClientParams.server != "mosh-server" {
        // If the server is specific, go after that one only.
        sequence = [UseMoshOnPath(path: moshClientParams.server)]
      } else {
        sequence = [UseMoshOnPath(path: moshClientParams.server),
                    UseMoshOnPath.staticMosh(),
                    InstallStaticMosh(onCancel: { [weak self] in self?.kill() }, logger: self.logger)]
      }
      
      let pty: SSH.SSHClient.PTY?
      if command.noSshPty {
        pty = nil
      } else {
        pty = SSH.SSHClient.PTY(rows: Int32(self.device.rows), columns: Int32(self.device.cols))
      }
      
      var sshError: Error? = nil
      var _moshServerParams: MoshServerParams? = nil
      self.sshCancellable = SSHClient.dial(hostName, with: config)
        .flatMap { self.bootstrapMoshServer(on: $0,
                                            sequence: sequence,
                                            experimentalRemoteIP: moshClientParams.experimentalRemoteIP,
                                            args: moshServerStartupArgs,
                                            withPTY: pty) }
        //.print()
        .handleEvents(receiveCancel: { [weak self] in
          if let self = self {
            self.currentRunLoop.run(until: Date(timeIntervalSinceNow: 0.5))
            awake(runLoop: currentRunLoop)
          }
        })
        .sink(
          receiveCompletion: { [weak self] completion in
            switch completion {
            case .failure(let error):
              sshError = error
            default:
              break
            }
            self?.kill()
          },
          receiveValue: { params in
            _moshServerParams = params
          })

      self.isRunloopRunning = true
      awaitRunLoop(currentRunLoop)
      self.isRunloopRunning = false

      if let error = sshError {
        throw error
      }

      guard let _moshServerParams = _moshServerParams else {
        throw MoshError.NoMoshServerArgs
      }
      moshServerParams = _moshServerParams
      log.info("Remote Mosh server bootstrapped with params \(moshServerParams)")
    }

    return MoshParams(server: moshServerParams, client: moshClientParams)
  }

  private func moshMain(_ moshParams: MoshParams) -> Int32 {
    let originalRawMode = device.rawMode
    self.device.rawMode = true

    defer {
      device.rawMode = originalRawMode
    }

    let _selfRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    let encodedState = [UInt8](moshParams.encodedState ?? Data())

    if let localesPath = Bundle.main.path(forResource: "locales", ofType: "bundle"),
       let ccharLocalesPath = localesPath.cString(using: .utf8) {
      setenv("PATH_LOCALE", ccharLocalesPath, 1)
    }
    
    self.sessionParams.cleanEncodedState()
    
    mosh_main(
      self.stdin.file,
      self.stdout.file,
      self.device.window(),
      self.stateCallback,
      _selfRef,
      moshParams.ip,
      moshParams.port,
      moshParams.key,
      moshParams.predictionMode,
      encodedState,
      encodedState.count,
      moshParams.predictOverwrite
    )

    return 0
  }

  private func getMoshServerStartupArgs(udpPort: String?,
                                 colors: String?,
                                 exec: String?) -> String {
    let localeFallback = "LANG=\(String(cString: getenv("LANG")))"
    
    var args = ["new", "-s", "-c", colors ?? "256", "-l", localeFallback]

    if let udpPort = udpPort {
      args.append(contentsOf: ["-p", udpPort])
    }
    if let exec = exec {
      args.append(contentsOf: ["--", exec])
    }

    return args.joined(separator: " ")
  }

  private func bootstrapMoshServer(on client: SSHClient,
                                   sequence: [MoshBootstrap],
                                   experimentalRemoteIP: BKMoshExperimentalIP,
                                   args: String,
                                   withPTY pty: SSH.SSHClient.PTY? = nil) -> AnyPublisher<MoshServerParams, Error> {
    let log = logger.log("bootstrapMoshServer")
    log.info("Trying bootstrap with sequence: \(sequence), experimental: \(experimentalRemoteIP), args: \(args)")
    
    if sequence.isEmpty {
      return Fail(error: MoshError.NoBinaryAvailable).eraseToAnyPublisher()
    }

    func tryBootstrap(_ sequence: [MoshBootstrap]) -> AnyPublisher<MoshServerParams, Error> {
      if sequence.count == 0 {
        return .fail(error: MoshError.NoMoshServerArgs)
      }

      let bootstrap = sequence.first!
      log.info("Trying \(bootstrap)")
      return Just(bootstrap)
        .flatMap { $0.start(on: client) }
        .map { moshServerPath -> String in
          if experimentalRemoteIP == BKMoshExperimentalIPRemote {
            return "echo \"MOSH SSH_CONNECTION $SSH_CONNECTION\" && \(moshServerPath) \(args)"
          } else {
            return "\(moshServerPath) \(args)"
          }
        }
        .flatMap {
          log.info("Connecting to \($0)")
          return client.requestExec(command: $0, withPTY: pty)
        }
        .flatMap { s -> AnyPublisher<DispatchData, Error> in
          // The PTY will multiplex, so we only try to parse stdout in all cases.
          s.read(max: 1024).eraseToAnyPublisher() //.zip(s.read_err(max: 1024)).eraseToAnyPublisher()
        }
        .flatMap { data -> AnyPublisher<MoshServerParams, Error> in
          return Just(data)
            .map {
              String(decoding: $0 as AnyObject as! Data, as: UTF8.self)
            }
            .tryMap { output -> MoshServerParams in
              log.info("Command output: \(output)")
              // IP Resolution
              switch experimentalRemoteIP {
              case BKMoshExperimentalIPRemote:
                // remote - echo SSH_CONNECTION on remote for parsing.
                return try MoshServerParams(parsing: output, remoteIP: nil)
              case BKMoshExperimentalIPLocal:
                // local - resolve address on its own.
                // TODO Or to INET6 from CLI flag
                let remoteIP = try self.resolveAddress(host: client.host, port: client.options.port, family: nil)
                return try MoshServerParams(parsing: output, remoteIP: remoteIP)
              default:
                // default - get it from the established SSH Connection.
                return try MoshServerParams(parsing: output, remoteIP: client.clientAddressIP())
              }
            }
            .catch{ err in
              //let err = String(decoding: err as AnyObject as! Data, as: UTF8.self)
              log.warn("Bootstrap failed with \(err)")
              var sequence = sequence
              sequence.removeFirst()
              return tryBootstrap(sequence)
            }
            .eraseToAnyPublisher()
        }
        .print()
        .eraseToAnyPublisher()
    }

    return tryBootstrap(sequence)
  }

  private func copyToSession(moshParams: MoshParams) {
    if let sessionParams = self.sessionParams as? MoshParams {
      sessionParams.copy(from: moshParams)
    }
  }

  // Migrated from Objc, based on...
  // getaddrinfo
  // https://stackoverflow.com/questions/39857435/swift-getaddrinfo
  // getnameinfo
  // https://stackoverflow.com/questions/44478074/swift-getnameinfo-unreliable-results-for-ipv6
  private func resolveAddress(host: String, port: String?, family: Int32?) throws -> String {
    guard let port = (port ?? "22").cString(using: .utf8) else {
      throw MoshError.AddressInfo("Invalid port")
    }
    var hints = addrinfo(
      ai_flags: 0,
      ai_family: family ?? AF_UNSPEC,
      ai_socktype: SOCK_STREAM,
      ai_protocol: IPPROTO_TCP,
      ai_addrlen: 0,
      ai_canonname: nil,
      ai_addr: nil,
      ai_next: nil)
    var result: UnsafeMutablePointer<addrinfo>? = nil
    let err = getaddrinfo(host, port, &hints, &result)
    if err != 0 {
      throw MoshError.AddressInfo("getaddrinfo failed with \(err)")
    }
    defer { freeaddrinfo(result) }

    guard let firstAddr = result?.pointee else {
      throw MoshError.AddressInfo("No address info found")
    }
    for ai in sequence(first: firstAddr, next: { $0.ai_next?.pointee }) {
      if (ai.ai_family != AF_INET && ai.ai_family != AF_INET6) {
        continue;
      }

      var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      var port = port
      if getnameinfo(ai.ai_addr, ai.ai_addrlen,
                     &buffer, socklen_t(buffer.count),
                     &port, socklen_t(port.count),
                     NI_NUMERICHOST | NI_NUMERICSERV) != 0 {
        print("getnameinfo failed")
        continue
      }

      return String(cString: buffer)
    }
    
    throw MoshError.AddressInfo("Could not resolve address through getnameinfo.")
  }

  @objc public override func kill() {
    if isRunloopRunning {
      // Cancelling here makes sure the flows are cancelled.
      // Trying to do it at the runloop has the issue that flows may continue running.
      print("Kill received")
      self.currentRunLoop.run(until: Date(timeIntervalSinceNow: 0.5))
      awake(runLoop: currentRunLoop)
      sshCancellable = nil
    } else {
      // MOSH-ESC .
      self.device.write(String("\(self.escapeKey)\u{2e}"))
      pthread_kill(self.tid, SIGINT)
    }
  }

  @objc public override func suspend() {
    if sshCancellable == nil {
      suspendSemaphore = DispatchSemaphore(value: 0)
      // MOSH-ESC C-z
      self.device.write(String("\(self.escapeKey)\u{1a}"))
      print("Session suspend called")
      let _ = suspendSemaphore!.wait(timeout: (DispatchTime.now() + 2.0))
      print("Session suspended")
    }
  }

  @objc public override func sigwinch() {
    pthread_kill(self.tid, SIGWINCH);
  }
  
  @objc public override func handleControl(_ control: String!) -> Bool {
    if isRunloopRunning {
      self.kill()
      return true
    } else {
      return false
    }
  }
  
  func onStateEncoded(_ encodedState: Data) {
    self.sessionParams.encodedState = encodedState
    print("Encoding session")
    if let sema = suspendSemaphore {
      sema.signal()
    }
  }

  func die(message: String) -> Int32 {
    print(message, to: &stderr)
    return -1
  }
  
  deinit {
    print("Mosh is out")
  }
}

extension MoshParams {
  convenience init(server: MoshServerParams, client: MoshClientParams) {
    self.init()

    self.key = server.key
    self.port = server.udpPort
    self.ip = server.remoteIP
    self.predictionMode = String(describing: client.predictionMode)
    self.predictOverwrite = client.predictOverwrite
    self.serverPath = client.server
  }
}

struct MoshLogger {
  var handler = [BlinkLogging.LogHandlerFactory]()
  init(output: OutputStream, logLevel: BlinkLogLevel = .error) {
    handler.append(
      {
        $0
          .filter(logLevel: logLevel)
          .format { [ ($0[.component] as? String)?.appending(":") ?? "global:",
                    $0[.message] as? String ?? ""
                  ].joined(separator: " ") }
          .sink(receiveValue: { print($0[.message]) })
        //.sinkToStream(output)
      }
    )
  }
  
  func log(_ component: String) -> BlinkLogger {
    BlinkLogger(component, handlers: handler)
  }
}

extension Publisher {
  fileprivate func sinkToStream(_ stream: OutputStream) -> AnyCancellable where Self.Output == [BlinkLogKeys:Any] {
    let out = NonStdIO(err: stream)
    return sink(receiveCompletion: { _ in },
                receiveValue: {
      out.printError($0[.message] ?? "")
    })
  }
}
