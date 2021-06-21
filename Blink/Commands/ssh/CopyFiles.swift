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
import Foundation

import ArgumentParser
import BlinkFiles
import SSH
import NonStdIO


// TODO Wildcards on source will be matched by the shell, and throw No Match if there are none.
// Test on new ios_system and fix there.
@_cdecl("copyfiles_main")
public func copyfiles_main(argc: Int32, argv: Argv) -> Int32 {
  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkCopy()
  session.registerSSHClient(cmd)
  let rc = cmd.start(argc, argv: argv.args(count: argc))
  session.unregisterSSHClient(cmd)

  return rc
}

struct BlinkCopyCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    // Optional abstracts and discussions are used for help output.
    abstract: "Copy SOURCE to DEST or multiple SOURCEs to a DEST directory.",
    discussion: """
    """,
    // Commands can define a version for automatic '--version' support.
    version: "1.0.0")

  @Flag(name: .shortAndLong)
  var verbose: Int

  @Argument(help: "SOURCE(s)",
            transform: { try FileLocationPath($0) })
  var source: FileLocationPath

  @Argument(help: "DEST",
            transform: { try FileLocationPath($0) })
  var destination: FileLocationPath
}

enum BlinkFilesProtocols: String {
  case local = "local"
  case scp = "scp"
  case sftp = "sftp"
}

class FileLocationPath {
  var fullPath: String

  var proto: BlinkFilesProtocols?
  var hostPath: String? // user@host#port
  var filePath: String

  init(_ path: String) throws {
    self.fullPath = path

    let components = self.fullPath.components(separatedBy: ":")
    
    switch components.count {
    case 1:
      self.filePath = components[0]
      self.proto = .local
    case 2:
      self.filePath = components[1]
      var host = components[0]
      if host.starts(with: "/") {
        host.removeFirst()
      }
      self.hostPath = host
    case 3:
      self.filePath = components[2]
      self.hostPath = components[1]
      var proto = components[0]
      if proto.starts(with: "/") {
        proto.removeFirst()
      }
      self.proto = BlinkFilesProtocols(rawValue: proto)
    default:
      throw ArgumentParser.ValidationError("Path format can only have three components /<protocol>:<host>:<path>")
    }
  }
}


public class BlinkCopy: NSObject {
  var copyCancellable: AnyCancellable?
  let device: TermDevice = tty()
  let currentRunLoop = RunLoop.current
  var stdout = OutputStream(file: thread_stdout)
  var stderr = OutputStream(file: thread_stderr)
  var command: BlinkCopyCommand!

  public func start(_ argc: Int32, argv: [String]) -> Int32 {
    // We can use the same command for different default protocols.
    let defaultRemoteProtocol: BlinkFilesProtocols
    switch argv[0] {
    case "fcp":
      defaultRemoteProtocol = .sftp
    case "scp":
      defaultRemoteProtocol = .sftp
    case "sftp":
      defaultRemoteProtocol = .sftp
    default:
      print("Unknown init for copy command. This should not happen.", to: &stderr)
      return -1
    }

    do {
      command = try BlinkCopyCommand.parse(Array(argv[1...]))
    } catch {
      let message = BlinkCopyCommand.message(for: error)
      print(message, to: &stderr)
      return -1
    }

    // Connect to the destination first, as it will be the one driving the operation.
    let destProtocol = command.destination.proto ?? defaultRemoteProtocol

    let destTranslator = (destProtocol == .local) ? localTranslator(to: command.destination.filePath) :
      remoteTranslator(toFilePath: command.destination.filePath, atHost: command.destination.hostPath!, using: destProtocol, isSource: false)

    let sourceProtocol = command.source.proto ?? defaultRemoteProtocol
    let sourceTranslator = (sourceProtocol == .local) ? localTranslator(to: command.source.filePath) :
      remoteTranslator(toFilePath: command.source.filePath, atHost: command.source.hostPath!, using: sourceProtocol)

    // TODO Output object for reports
    var rc: Int32 = 0
    var currentFile: String?
    var currentCopied: UInt64 = 0
    var currentSpeed: Double?
    var startTimestamp = 0
    var lastElapsed = 0
    copyCancellable = destTranslator.flatMap { d -> CopyProgressInfo in
      return sourceTranslator.flatMap {
        $0.translatorsMatching(path: self.command.source.filePath)
      }
        .reduce([] as [Translator]) { (all, t) in
          var new = all
          new.append(t)
          return new
        }.flatMap { d.copy(from: $0) }.eraseToAnyPublisher()
    }.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        print("Copy failed. \(error)", to: &self.stderr)
        rc = -1
      }
      awake(runLoop: self.currentRunLoop)
    }, receiveValue: { (file, size, written) in
      // ProgressReport object, which we can use here or at the Dashboard.
      if currentFile != file {
        currentFile = file
        currentCopied = written
        startTimestamp = Int(Date().timeIntervalSince1970)
        currentSpeed = nil
        lastElapsed = 0
      } else {
        currentCopied += written
        // Speed only updated by the second
        let elapsed = Int(Date().timeIntervalSince1970) - startTimestamp
        if elapsed > lastElapsed {
          lastElapsed = elapsed
          let kbCopied = Double(currentCopied / 1024)
          currentSpeed = kbCopied / Double(elapsed)
        }
      }
      if currentCopied == size {
        print("\u{001B}[K\(file) - \(currentCopied) of \(size) - \(currentSpeed ?? 0)kb/S", to: &self.stdout)
      } else {
        print("\r\u{001B}[K\(file) - \(currentCopied) of \(size) - \(currentSpeed ?? 0)kb/S", terminator: "", to: &self.stdout)
      }
    })

    awaitRunLoop(currentRunLoop)

    return rc
  }

  func localTranslator(to path: String) -> AnyPublisher<Translator, Error> {
    return .just(BlinkFiles.Local())
  }

  func remoteTranslator(toFilePath filePath: String, atHost hostPath: String, using proto: BlinkFilesProtocols, isSource: Bool = true) -> AnyPublisher<Translator, Error> {
    // At the moment everything is just SSH. At some point we should have a factory.
    let sshCommand: SSHCommand
    let sshOptions: ConfigFileOptions
    var params = [hostPath]
    
    do {
      // Pass verbosity
      if command.verbose > 0 {
        let v = String(format: "-%@", String(repeating: "v", count: command.verbose))
        params.append(v)
      }
      sshCommand = try SSHCommand.parse(params)
      sshOptions = try sshCommand.connectionOptions.get()
    } catch {
      let message = SSHCommand.message(for: error)
      return .fail(error: CommandError(message: message))
    }

    let (hostName, config) = SSHClientConfigProvider.config(command: sshCommand, using: device)
    return SSHPool.dial(hostName, with: config, connectionOptions: sshOptions)
      .flatMap { conn -> AnyPublisher<Translator, Error> in
        return conn.requestSFTP().map { $0 as Translator }.eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }

  @objc func sigwinch() { }
  
  // Make signals objc funcs so we can duck type them.
  @objc func kill() {
    copyCancellable?.cancel()

    awake(runLoop: currentRunLoop)
  }
}
