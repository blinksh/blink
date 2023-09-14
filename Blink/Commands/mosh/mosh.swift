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

import SSH
import ios_system

@_cdecl("blink_mosh_main")
public func blink_mosh_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkMosh()
  return cmd.start(argc, argv: argv.args(count: argc))
}

// TODO Move this errors out of here as they will be for all mosh
enum MoshError: Error {
  case NoBinaryAvailable
  case NoMoshServerArgs
}


// TODO
// struct MoshCommand: ParsableCommand {
// }


@objc public class BlinkMosh: NSObject {
  var exitCode: Int32 = 0
  var sshCancellable: AnyCancellable? = nil
  let device = tty()
  let currentRunLoop = RunLoop.current
  var stdin = InputStream(file: thread_stdin)
  var stdout = OutputStream(file: thread_stdout)
  var stderr = OutputStream(file: thread_stderr)
  var bootstrapSequence: [MoshBootstrap] = []

  // TODO A different main will process if there is any initial state first, otherwise
  // call here.

  @objc public func start(_ argc: Int32, argv: [String]) -> Int32 {
    let host: BKSSHHost
    let config: SSHClientConfig
    let hostName: String

    let originalRawMode = device.rawMode
    defer {
      device.rawMode = originalRawMode
    }

    do {
      // TODO ssh config from command + ssh setup
      host = try BKConfig().bkSSHHost("loc")//moshCommand.hostAlias) // extending: moshCommand.bkSSHHost())
      hostName = host.hostName! // ?? moshCommand.hostName
      config = try SSHClientConfigProvider.config(host: host, using: device)
    } catch {
      print("Configuration error - \(error)", to: &stderr)
      return -1
    }

    let moshServerArgs = getMoshServerArgs(port: nil, colors: nil, exec: nil)

    // TODO Enforce path only or push-only depending on flags?.
    bootstrapSequence = [UseMoshOnPath(path: "/usr/local/bin/mosh-server")] // UseStaticMosh

    var moshServerParams: MoshServerParams? = nil
    sshCancellable = SSHClient.dial(hostName, with: config)
      .flatMap { self.startMoshServer(on: $0, args: moshServerArgs) }
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

    // Early exit if we could not connect
    guard let moshServerParams = moshServerParams else {
      // TODO Not sure I need this one here as we have no other thread. It should close as-is.
      // It does not look like we do. But will keep an eye on Stream Deinit.
      //RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
      return exitCode
    }

    self.device.rawMode = true

    // TODO Using SSH Host, but the Host may not be resolved,
    // we need to expose one level deeper, at the socket level.
    var _selfRef = CFBridgingRetain(self);
    mosh_main(
      self.stdin.file,
      self.stdout.file,
      &self.device.win,
      nil,//&__state_callback,
      &_selfRef,
      moshServerParams.remoteIP,
      moshServerParams.udpPort,
      moshServerParams.key,
      "adaptive", // predictionMode,
      [], // encoded state *CChar U8
      0, // encoded state bytes
      "no" // predictoverwrite
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

  private func getMoshServerArgs(port: String?,
                                 colors: String?,
                                 exec: String?) -> String {
    // TODO Locale as args
    var moshServerArgs = ["new", "-s", "-c", colors ?? "256", "-l LC_ALL=en_US.UTF-8"]

    if let port = port {
      moshServerArgs.append(contentsOf: ["-p", port])
    }
    if let exec = exec {
      moshServerArgs.append(contentsOf: ["--", exec])
    }

    return moshServerArgs.joined(separator: " ")
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

  @objc public func kill() {
    // Cancelling here makes sure the flows are cancelled.
    // Trying to do it at the runloop has the issue that flows may continue running.
    print("Kill received")
    sshCancellable = nil

    awake(runLoop: currentRunLoop)
  }
}
