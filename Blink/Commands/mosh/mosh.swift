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
  case NoMoshServerArgs
}

@objc public class BlinkMosh: Session {
  var exitCode: Int32 = 0
  var sshCancellable: AnyCancellable? = nil
  //var command: MoshCommand!
  // let device = tty()
  let currentRunLoop = RunLoop.current
  var stdin: InputStream!
  var stdout: OutputStream!
  var stderr: OutputStream!
  var bootstrapSequence: [MoshBootstrap] = []
  private var initialMoshParams: MoshParams? = nil
  private let mcpSession: MCPSession
  private var suspendSemaphore: DispatchSemaphore? = nil

  let stateCallback: mosh_state_callback = { (context, buffer, size) in
    // TODO buffer nil?
    let data = Data(bytes: buffer!, count: size)
    let session = Unmanaged<BlinkMosh>.fromOpaque(context!).takeUnretainedValue()
    session.onStateEncoded(data)
  }

  @objc init!(mcpSession: MCPSession, device: TermDevice!, andParams params: SessionParams!) {
    self.mcpSession = mcpSession
    super.init(device: device, andParams: params)

    self.stdin = InputStream(file: stream.in)
    self.stdout = OutputStream(file: stream.out)
    self.stderr = OutputStream(file: stream.err)
  }

  @objc public override func main(_ argc: Int32, argv: Argv) -> Int32 {
    mcpSession.setActiveSession()

    // TODO MOSH_ESCAPE_KEY

    // In objc, sessionParams is a covariable for moshparams.
    // Here we need to force transform.
    if let initialMoshParams = self.sessionParams as? MoshParams,
       let _ = initialMoshParams.encodedState {
      moshMain(initialMoshParams)
      return 0
    } else {
      let command: MoshCommand
      do {
        command = try MoshCommand.parse(argv.args(count: argc))
        //command = try MoshCommand.parse(Array(argv[1...]))
      } catch {
        let message = MoshCommand.message(for: error)
        print("\(message)", to: &stderr)
        return -1
      }
      
      let moshParams: MoshParams
      do {
        try connectMoshServer(command)
      } catch {
        return die(message: "(\(error)")
      }
      
      //return start(argc, argv: argv.args(count: argc))
    }
  }

  func connectMoshServer(_ command: MoshCommand) throws {
    
  }
  
  @objc public func start(_ argc: Int32, argv: [String]) -> Int32 {
    do {
      self.command = try MoshCommand.parse(Array(argv[1...]))
    } catch {
      let message = MoshCommand.message(for: error)
      print("\(message)", to: &stderr)
      return -1
    }

    let host: BKSSHHost
    let config: SSHClientConfig
    let hostName: String
    do {
      host = try BKConfig().bkSSHHost(self.command.hostAlias, extending: self.command.bkSSHHost())
      hostName = host.hostName ?? self.command.hostAlias
      config = try SSHClientConfigProvider.config(host: host, using: device)
    } catch {
      return die(message: "Configuration error - \(error)")
    }

    // prediction modes, etc...
    // IP resolution,
    // This will come from host + command
    let moshClientParams = MoshClientParams(extending: self.command)

    var moshServerParams: MoshServerParams? = nil
    // TODO Figure out how to continue splitting this function?
    // If we have a key, we do not need moshServerArgs to query the connection.
    if let customKey = self.command.customKey {
      guard let customUDPPort = moshClientParams.customUDPPort else {
        return die(message: "If MOSH_KEY is set port is required. (-p)")
      }

      moshServerParams = MoshServerParams(key: customKey, udpPort: customUDPPort, remoteIP: nil)
    } else {
      let moshServerStartupArgs = getMoshServerStartupArgs(udpPort: moshClientParams.customUDPPort,
                                                           colors: nil,
                                                           exec: self.command.remoteCommand)

      // TODO Enforce path only or push-only depending on flags?.
      bootstrapSequence = [UseMoshOnPath(path: moshClientParams.server)] // UseStaticMosh

      sshCancellable = SSHClient.dial(hostName, with: config)
        .flatMap { self.startMoshServer(on: $0, args: moshServerStartupArgs) }
        .sink(
          receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
              print("Mosh error. \(error)", to: &self.stderr)
              self.exitCode = -1
              self.kill()
            default:
              break
            }
          },
          receiveValue: { params in
            // From Combine, output from running mosh-server.
            print(params)
            moshServerParams = params
            awake(runLoop: self.currentRunLoop)
          })

      awaitRunLoop(currentRunLoop)
    }

    // Early exit if we could not connect
    guard let moshServerParams = moshServerParams else {
      // TODO Not sure I need this one here as we have no other thread. It should close as-is.
      // It does not look like we do. But will keep an eye on Stream Deinit.
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
      return exitCode
    }

    self.device.rawMode = true

    // TODO the self.initialMoshParams here may not be needed anymore. Depends on how we structure the main now.
    let moshParams = self.initialMoshParams ?? MoshParams(server: moshServerParams, client: moshClientParams)
    self.copyToSession(moshParams: moshParams)
    // TODO This is incorrect. We cannot replace sessionParams as there are multiple objects pointing to it.
    // We need to copy moshParams into sessionParams

    // TODO Using SSH Host, but the Host may not be resolved,
    // we need to expose one level deeper, at the socket level.
    let _selfRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    mosh_main(
      self.stdin.file,
      self.stdout.file,
      &self.device.win,
      self.stateCallback,
      _selfRef,
      moshParams.ip,
      moshParams.port,
      moshParams.key,
      moshParams.predictionMode,
      [], // encoded state *CChar U8
      0, // encoded state bytes
      moshParams.predictOverwrite // predictoverwrite
    // [self.sessionParams.ip UTF8String],
    // [self.sessionParams.port UTF8String],
    // [self.sessionParams.key UTF8String],
    // [self.sessionParams.predictionMode UTF8String],
    // encodedState.bytes,
    // encodedState.length,
    // [self.sessionParams.predictOverwrite UTF8String]
    )

    return 0
  }

  private func moshMain(_ moshParams: MoshParams) {
    let originalRawMode = device.rawMode
    defer {
      device.rawMode = originalRawMode
    }
    
    let _selfRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    mosh_main(
      self.stdin.file,
      self.stdout.file,
      &self.device.win,
      self.stateCallback,
      _selfRef,
      moshParams.ip,
      moshParams.port,
      moshParams.key,
      moshParams.predictionMode,
      [], // encoded state *CChar U8
      0, // encoded state bytes
      moshParams.predictOverwrite // predictoverwrite
    // [self.sessionParams.ip UTF8String],
    // [self.sessionParams.port UTF8String],
    // [self.sessionParams.key UTF8String],
    // [self.sessionParams.predictionMode UTF8String],
    // encodedState.bytes,
    // encodedState.length,
    // [self.sessionParams.predictOverwrite UTF8String]
    )
  }
  
  private func getMoshServerStartupArgs(udpPort: String?,
                                 colors: String?,
                                 exec: [String]?) -> String {
    // TODO Locale as args
    var args = ["new", "-s", "-c", colors ?? "256", "-l LC_ALL=en_US.UTF-8"]

    if let udpPort = udpPort {
      args.append(contentsOf: ["-p", udpPort])
    }
    if let exec = exec {
      args.append(contentsOf: ["--", exec.joined(separator: " ")])
    }

    return args.joined(separator: " ")
  }

  private func startMoshServer(on client: SSHClient, args: String) -> AnyPublisher<MoshServerParams, Error> {
    if bootstrapSequence.isEmpty {
      return Fail(error: MoshError.NoBinaryAvailable).eraseToAnyPublisher()
    }

    return Just(bootstrapSequence.removeFirst())
      .flatMap { $0.start(on: client) }
    // .catch - NoBinary. Should it continue or should it stop?
    // It should stop, because that would be the user expectation.
    // And if it shouldn't then it is the start responsibility to indicate how.
      .map { moshServerPath in
        "\(moshServerPath) \(args)"
      }
      // TODO Special SSH exec features like starting in a pty, etc...
      .flatMap {
        client.requestExec(command: $0)
      }
      .flatMap { s -> AnyPublisher<DispatchData, Error> in
        s.read(max: 1024)
      }
      .map {
        // TODO If Data is empty, it means there was no mosh-server binary.
        // In this case, we try with the next method.
        // TODO If mosh-server run but NoMoshServerArgs, then we crash.
        String(decoding: $0 as AnyObject as! Data, as: UTF8.self)
      }
      .tryMap { output in
        // TODO Take into account the way to resolve the IP instead.
        var params = try MoshServerParams(parsing: output)
        if params.remoteIP == nil {
          params = MoshServerParams(key: params.key, udpPort: params.udpPort, remoteIP: client.clientAddressIP())
        }
        return params
      }
      .map { params in
        print(params)
        return params
      }
      .eraseToAnyPublisher()
  }

  private func copyToSession(moshParams: MoshParams) {
    if let sessionParams = self.sessionParams as? MoshParams {
      sessionParams.copy(from: moshParams)
    }
  }

  @objc public override func kill() {
    // Cancelling here makes sure the flows are cancelled.
    // Trying to do it at the runloop has the issue that flows may continue running.
    print("Kill received")
    sshCancellable = nil
    awake(runLoop: currentRunLoop)
  }

  @objc public override func suspend() {
    suspendSemaphore = DispatchSemaphore(value: 0)
    // TODO NSString stringWithFormat:@"%@%@", _escapeKey ?: @"\x1e", @"\x1a"
    self.device.write(String("\u{1e}\u{1a}"))
    print("Session suspend called")
    let _ = suspendSemaphore!.wait(timeout: (DispatchTime.now() + 2.0))
    print("Session suspended")
    //dispatch_semaphore_wait(_sema, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
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
    // TODO self.startupCmd - maybe even use on SSH as well?
    // TODO self.experimentalRemoteIp
  }
}
