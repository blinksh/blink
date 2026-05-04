//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2026 Blink Mobile Shell Project
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
import Combine
import Dispatch

import ArgumentParser
import BlinkConfig
import BlinkFiles
import SSH
import ios_system


// Launch in a 'sh' shell for better compatibility
fileprivate let copyCommand =
"sh -c 'umask 077; test -d ~/.ssh || mkdir ~/.ssh ; cat >> .ssh/authorized_keys; test -x /sbin/restorecon && /sbin/restorecon .ssh .ssh/authorized_keys'"


struct BlinkSSHCopyIDCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "ssh-copy-id",
    abstract: "Install a public key on a remote host's authorized_keys.",
    discussion: """
    ssh-copy-id appends the named identity's public key to ~/.ssh/authorized_keys on the remote host, creating the directory if needed.
    """,
    version: "1.0.0"
  )

  @Flag(name: .shortAndLong)
  var verbosity: Int

  @Argument(help: .init(
    "Identity (key) name as registered in Blink",
    valueName: "identity_file"
  ))
  var identityName: String

  @Argument(help: .init(
    "[user@]host[#port]",
    valueName: "destination"
  ))
  var userAtHost: String
}


@_cdecl("blink_ssh_copyid")
public func blink_ssh_copyid(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkSSHCopyID(mcp: session)
  session.registerSSHClient(cmd)
  let rc = cmd.start(argc, argv: argv.args(count: argc))
  session.unregisterSSHClient(cmd)
  return rc
}


@objc public class BlinkSSHCopyID: NSObject {
  private typealias SSHConnection = AnyPublisher<SSH.SSHClient, Error>

  let device: TermDevice
  let outstream: Int32
  let errstream: Int32
  var stdout = OutputStream(file: thread_stdout)
  var stderr = OutputStream(file: thread_stderr)

  private var _mcp: MCPSession
  let currentRunLoop = RunLoop.current
  var timer: Timer?

  var connectionCancellable: AnyCancellable?
  var connection: SSH.SSHClient?
  var stream: SSH.Stream?
  var outDispatchStream: DispatchOutputStream?
  var errDispatchStream: DispatchOutputStream?
  var exitCode: Int32 = 0

  init(mcp: MCPSession) {
    _mcp = mcp
    outstream = fileno(thread_stdout)
    errstream = fileno(thread_stderr)
    device = tty()
    super.init()
  }

  public func start(_ argc: Int32, argv: [String]) -> Int32 {
    let cmd: BlinkSSHCopyIDCommand
    do {
      cmd = try BlinkSSHCopyIDCommand.parse(Array(argv[1...]))
    } catch {
      let message = BlinkSSHCopyIDCommand.message(for: error)
      print(message, to: &stderr)
      return -1
    }

    guard let pubKey = BKPubKey.withID(cmd.identityName)?.publicKey else {
      print("ERROR: No identity found with name '\(cmd.identityName)'.", to: &stderr)
      return -1
    }

    // Reuse the standard SSHCommand parser so identity, user@host#port,
    // verbose, resolve through the same code path.
    var sshArgs: [String] = [cmd.userAtHost]
    if cmd.verbosity > 0 {
      sshArgs.append("-" + String(repeating: "v", count: cmd.verbosity))
    }

    let host: BKSSHHost
    let hostName: String
    let config: SSHClientConfig
    do {
      let sshCommand = try SSHCommand.parse(sshArgs)
      let resolved = try sshCommand.resolveHost()
      host = resolved.host
      hostName = resolved.hostName
      config = try SSHClientConfigProvider.config(host: host, using: device)
    } catch {
      print("Configuration error - \(error)", to: &stderr)
      return -1
    }

    let connect: SSHConnection = SSHPool.dial(
      hostName,
      with: config,
      withControlMaster: .no,
      withProxy: { [weak self] in
        guard let self = self else { return }
        self._mcp.setActiveSession()
        BlinkSSH.executeProxyCommand(command: $0, sockIn: $1, sockOut: $2)
      }
    )

    connectionCancellable = connect
      .flatMap { conn -> AnyPublisher<SSH.Stream, Error> in
        self.connection = conn
        if let banner = conn.issueBanner, !banner.isEmpty {
          print(banner, to: &self.stdout)
        }
        conn.handleSessionException = { error in
          print("Exception received \(error)", to: &self.stderr)
          self.kill()
        }
        return conn.requestExec(command: copyCommand)
      }
      .sink(receiveCompletion: { completion in
        if case .failure(let error) = completion {
          print("Error connecting to \(cmd.userAtHost). \(error)", to: &self.stderr)
          self.exitCode = -1
          self.kill()
        }
      }, receiveValue: { s in
        self.stream = s
        self.attach(s, pubKey: pubKey)
      })

    awaitRunLoop()

    stream?.cancel()
    outDispatchStream?.close()
    errDispatchStream?.close()
    stream = nil
    outDispatchStream = nil
    errDispatchStream = nil

    connectionCancellable = nil
    connection = nil

    if exitCode == 0 {
      print("Identity '\(cmd.identityName)' installed on \(cmd.userAtHost).", to: &stdout)
    }

    return exitCode
  }

  private func attach(_ s: SSH.Stream, pubKey: String) {
    s.handleCompletion = { [weak self] in self?.kill() }
    s.handleFailure = { [weak self] error in
      guard let self = self else { return }
      print("Error: \(error)", to: &self.stderr)
      self.exitCode = -1
      self.kill()
    }

    let outDispatch = DispatchOutputStream(stream: dup(outstream))
    let errDispatch = DispatchOutputStream(stream: dup(errstream))
    self.outDispatchStream = outDispatch
    self.errDispatchStream = errDispatch

    s.connect(stdout: outDispatch,
              stdin: PubKeyWriterTo(pubKey: pubKey),
              stderr: errDispatch)
  }

  @objc public func sigwinch() {}

  @objc public func kill() {
    connectionCancellable = nil
    awake()
  }

  func awaitRunLoop() {
    let timer = Timer(timeInterval: TimeInterval(INT_MAX), repeats: true) { _ in }
    self.timer = timer
    self.currentRunLoop.add(timer, forMode: .default)
    CFRunLoopRun()
  }

  func awake() {
    let cfRunLoop = self.currentRunLoop.getCFRunLoop()
    self.timer?.invalidate()
    CFRunLoopStop(cfRunLoop)
  }
}

fileprivate class PubKeyWriterTo: WriterTo {
  let payload: DispatchData

  init(pubKey: String) {
    let bytes = Array((pubKey + "\n").utf8)
    self.payload = bytes.withUnsafeBytes { DispatchData(bytes: $0) }
  }

  func writeTo(_ w: Writer) -> AnyPublisher<Int, Error> {
    return w.write(payload, max: payload.count)
  }
}
