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
import ios_system

fileprivate let Version = "1.0.1"

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
    version: Version)

  @Flag(name: .shortAndLong)
  var verbose: Int

  @Flag(name: [.customShort("p")],
        help: "Preserve file attributes (permissions and timestamps)")
  var preserve: Bool = false

  @Flag(name: .shortAndLong,
        help: "Copy only when source is newer than destination, considering the timestamp. This includes -p.")
  var update: Bool = false

  @Argument(help: "SOURCE(s)",
            transform: { try FileLocationPath($0) })
  var source: FileLocationPath

  @Argument(help: "DEST",
            transform: { try FileLocationPath($0) })
  var destination: FileLocationPath = try! FileLocationPath(".")

  var preserveFlags: CopyAttributesFlag {
    preserve ? CopyAttributesFlag([.permissions, .timestamp]) : CopyAttributesFlag([])
  }
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

  // The FilePath cannot perform a full canonicalization and standardization of remote paths,
  // so what we do is to make them all look the same and let the Translator deal with standardizing and
  // canonicalizing further.
  // The FileLocationPath is always full, although it may contain special characters like ~.
  // Because of this, the FilePath must always start with a /
  init(_ path: String) throws {
    self.fullPath = path

    let components = self.fullPath.components(separatedBy: ":")

    switch components.count {
    case 1:
      // For a local path, we already have either absolute or relative to current
      let filePath = components[0]
      if filePath.starts(with: "/") {
        self.filePath = filePath
      } else if filePath.starts(with: "~") {
        self.filePath = ("/" as NSString).appendingPathComponent(filePath)
      } else {
        self.filePath = (FileManager.default.currentDirectoryPath as NSString)
          .appendingPathComponent(filePath)
      }

      self.proto = .local
    case 2:
      // For remote paths, we start with absolute / or relative to ~
      let filePath = components[1]
      if filePath.isEmpty {
        self.filePath = "/~"
      } else if filePath.starts(with: "/") {
        self.filePath = filePath
      } else if filePath.starts(with: "~") {
        self.filePath = "/\(filePath)"
      } else { // Relative
        self.filePath = "/~/\(filePath)"
      }

      var host = components[0]
      if host.starts(with: "/") {
        host.removeFirst()
      }
      self.hostPath = host
    default:
      let filePath = components[2...].joined(separator: ":")
      if filePath.isEmpty {
        self.filePath = "/~"
      } else if filePath.starts(with: "/") {
        self.filePath = filePath
      } else if filePath.starts(with: "~") {
        self.filePath = "/\(filePath)"
      } else { // Relative
        self.filePath = "/~/\(filePath)"
      }

      self.hostPath = components[1]
      var proto = components[0]
      if proto.starts(with: "/") {
        proto.removeFirst()
      }
      self.proto = BlinkFilesProtocols(rawValue: proto)
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

    let copyArguments = CopyArguments(preserve: command.preserveFlags,
                                      checkTimes: command.update)

    // Connect to the destination first, as it will be the one driving the operation.
    let destProtocol = command.destination.proto ?? defaultRemoteProtocol

    var destTranslator: AnyPublisher<Translator, Error>? = (destProtocol == .local) ? localTranslator(to: command.destination.filePath) :
      remoteTranslator(toFilePath: command.destination.filePath, atHost: command.destination.hostPath!, using: destProtocol, isSource: false)

    // Source
    let sourceProtocol = command.source.proto ?? defaultRemoteProtocol
    var sourceTranslator: AnyPublisher<Translator, Error>? = (sourceProtocol == .local) ? localTranslator(to: command.source.filePath) :
      remoteTranslator(toFilePath: command.source.filePath, atHost: command.source.hostPath!, using: sourceProtocol)

    var rc: Int32 = 0
    var rootFilePath: String!
    var currentFile = ""
    var displayFileName = ""
    var currentCopied: UInt64 = 0
    var currentSpeed: String?
    var startTimestamp = 0
    var lastElapsed = 0
    copyCancellable = destTranslator!.flatMap { d -> CopyProgressInfoPublisher in
      rootFilePath = d.current

      return sourceTranslator!
        .flatMap {
          $0.cloneWalkTo(self.command.source.filePath)
        }
        .flatMap {
          $0.translatorsMatching(path: self.command.source.filePath)
        }
        .reduce([] as [Translator]) { (all, t) in
          var new = all
          new.append(t)
          return new
        }
        .tryMap { source -> [Translator] in
          if source.count == 0 {
            throw CommandError(message: "Source not found")
          }
          return source
        }
        .flatMap { source -> AnyPublisher<([Translator], Translator), Error> in
          // Walk on destination, and it may have to be a directory or a file.
          return d.cloneWalkTo(self.command.destination.filePath)
            .tryCatch { error -> AnyPublisher<Translator, Error> in
              // If we are copying a single item, then we can create a file for it.
              guard source.count == 1 else {
                throw error
              }
              let newFileName = (self.command.destination.filePath as NSString).lastPathComponent
              let parentPath = (self.command.destination.filePath as NSString).deletingLastPathComponent
              return d.cloneWalkTo(parentPath)
                .flatMap { $0.create(name: newFileName, flags: O_WRONLY, mode: S_IRWXU) }
                .flatMap { $0.close() }
                .flatMap { _ in d.cloneWalkTo(self.command.destination.filePath) }
                .eraseToAnyPublisher()
            }
            .map { (source, $0) }
            .eraseToAnyPublisher()
        }
        .flatMap {
          $1.copy(from: $0, args: copyArguments)
        }.eraseToAnyPublisher()
    }.sink(receiveCompletion: { completion in
      if case let .failure(error) = completion {
        print("Copy failed. \(error)", to: &self.stderr)
        rc = -1
      }
      
      self.kill()
    }, receiveValue: { progress in //(file, size, written) in
      // ProgressReport object, which we can use here or at the Dashboard.
      if currentFile != progress.name {
        currentFile = progress.name
        let width = (Int(self.device.cols / 2) + 3)
        let trimmedPath = progress.name.replacingOccurrences(of: rootFilePath, with: "")
        if trimmedPath.count > width {
          displayFileName = "..." + trimmedPath.dropFirst(trimmedPath.count - width)
        } else {
          displayFileName = trimmedPath
        }
        currentCopied = progress.written
        startTimestamp = Int(Date().timeIntervalSince1970)
        currentSpeed = nil
        lastElapsed = 0
      } else {
        currentCopied += progress.written
        // Speed only updated by the second
        let elapsed = Int(Date().timeIntervalSince1970) - startTimestamp
        if elapsed > lastElapsed {
          lastElapsed = elapsed
          let kbCopied = Double(currentCopied / 1024)
          currentSpeed = String(format: "%.2f", kbCopied / Double(elapsed))
        }
      }

      let progressOutput = [
        "\u{001B}[K\(displayFileName)",
        "\(currentCopied)/\(progress.size)",
        "\(currentSpeed ?? "-")kb/S"].joined(separator: "\t")

      if progress.written == 0 {
        print(progressOutput, to: &self.stdout)
      } else {
        print(progressOutput, terminator: "\r", to: &self.stdout)
      }
    })

    // Run everything in its own loop...
    CFRunLoopRunInMode(.defaultMode, TimeInterval(INT_MAX), false)
    
    // ...and because of that, make another run after cleanup to let hanging self-loops close.
    sourceTranslator = nil
    destTranslator = nil
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    return rc
  }

  func localTranslator(to path: String) -> AnyPublisher<Translator, Error> {
    return .just(BlinkFiles.Local())
  }

  func remoteTranslator(toFilePath filePath: String, atHost hostPath: String, using proto: BlinkFilesProtocols, isSource: Bool = true) -> AnyPublisher<Translator, Error> {
    // At the moment everything is just SSH. At some point we should have a factory.
    let sshCommand: SSHCommand
    var params = [hostPath]
    let host: BKSSHHost
    let config: SSHClientConfig

    do {
      // Pass verbosity
      if command.verbose > 0 {
        let v = String(format: "-%@", String(repeating: "v", count: command.verbose))
        params.append(v)
      }
      sshCommand = try SSHCommand.parse(params)
      host = try BKConfig().bkSSHHost(sshCommand.hostAlias, extending: sshCommand.bkSSHHost())
      config = try SSHClientConfigProvider.config(host: host, using: device)
    } catch {
      let message = SSHCommand.message(for: error)
      return .fail(error: CommandError(message: message))
    }

    return SSHClient.dial(host.hostName ?? sshCommand.hostAlias, with: config)
    //return SSHPool.dial(hostName, with: config, connectionOptions: sshOptions)
      .flatMap { $0.requestSFTP() }
      .tryMap  { try SFTPTranslator(on: $0) }
      .eraseToAnyPublisher()
  }

  @objc func sigwinch() { }

  // Make signals objc funcs so we can duck type them.
  @objc func kill() {
    print("\r\nOperation cancelled", to: &self.stderr)
    copyCancellable = nil
    CFRunLoopStop(self.currentRunLoop.getCFRunLoop())
  }
}
