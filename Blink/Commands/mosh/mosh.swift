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

// struct MoshCommand: ParsableCommand {

// }

@objc public class BlinkMosh: NSObject {
  var sshCancellable: AnyCancellable?
  let device = tty()
  let currentRunLoop = RunLoop.current
  var stdout = OutputStream(file: thread_stdout)
  var stderr = OutputStream(file: thread_stderr)

  @objc public func start(_ argc: Int32, argv: [String]) -> Int32 {
    // ssh config from command + ssh setup
    let host: BKSSHHost
    let config: SSHClientConfig
    let hostName: String

    do {
      // TODO
      host = try BKConfig().bkSSHHost("loc")//moshCommand.hostAlias) // extending: moshCommand.bkSSHHost())
      hostName = host.hostName! // ?? moshCommand.hostName
      config = try SSHClientConfigProvider.config(host: host, using: device)
    } catch {
      print("Configuration error - \(error)", to: &stderr)
      return -1
    }

    // TODO pass MoshCommand
    let moshServerArgs = getMoshServerArgs(port: nil, colors: nil, exec: nil)

    // TODO The bootstrap returns a mosh-serve route, but we usually just run it.
    // We could enforce a "which", but that is not standard mosh bootstrap.
    // We should keep everything under one connection anyway.
    // - Try to run "mosh-server" as-is or from server route.
    //   - If the output does not match...
    // - Try to bootstrap "mosh-server". Ask user before uploading binary (but the check can be done)
    // ["mosh-server || provided-location", "bootstrap", ".fail"]
    // ["bootstrap"] only with the flag.
    // Do force-bootstrap only through flag.
    sshCancellable = SSHClient.dial(hostName, with: config)
      .flatMap { self.startMoshServer(on: $0, args: moshServerArgs) }
      .sink(
        receiveCompletion: { _ in
          awake(runLoop: self.currentRunLoop)
        },
        receiveValue: { conn in
          // From Combine, output from running mosh-server.
          print(conn)
        })

    awaitRunLoop(currentRunLoop)

    // parse output
    // Connect to server separately.
    return 0

  // connection, bootstrap and start mosh-server
  // connect to server
  }

  // TODO Pass command too for CLI configuration
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

  private func startMoshServer(on: SSHClient, args: String) -> AnyPublisher<(), Never> {
    
    Just(()).eraseToAnyPublisher()
  }
}
