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
import BuildCLI
import NonStdIO
import Machines
import ArgumentParser


struct BuildImageBuildCommand: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "build",
    abstract: "Build images"
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  @Option(
    name: .shortAndLong,
    help: "Name and optionally a tag in the 'name:tag' format"
  )
  var tag: String
  
  @Argument(
    help: "git url"
  )
  var gitURL: String
  
  func validate() throws {
    guard let _ = URL(string: gitURL)
    else {
      throw ValidationError("Invalid git url")
    }
  }
  
  func run() throws {
    let ip = try BuildCLIConfig.shared.machine(io: io).ip().awaitOutput()!
    let url = GitURL.from(url: URL(string: gitURL)!)
    var cmd = [
      "ssh", "-t",
      verboseOptions.verbose ? "-v" : "",
      "-A",
      "\(BuildCLIConfig.shared.sshUser)@\(ip)",
      "--", "build-ctl", tag, url.absoluteString]
    
    cmd = cmd.filter { !$0.isEmpty }
    printDebug("Executing : `\(cmd.joined(separator: " "))`")
    let (argc, argv, _) = Argv.build(cmd)
    let code = blink_ssh_main(argc: argc, argv: argv)
    throw ArgumentParser.ExitCode(code)
  }
}

struct BuildSSH: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "ssh",
    abstract: "SSH to container"
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  @Flag(
    name: .customShort("A"),
    help: "Enables forwarding of the authentication agent connection"
  )
  var agent: Bool = false
  
  @Option(
    name: .customShort("L", allowingJoined: true),
    help: "<localport>:<bind_address>:<remoteport> Specifies that the given port on the local (client) host is to be forwarded to the given host and port on the remote side."
  )
  var localPortForwards: [String] = []
  
  @Option(
    name: .customShort("R", allowingJoined: true),
    help: "port:host:hostport Specifies that the given port on the remote (server) host is to be forwarded to the given host and port on the local side."
  )
  var reversePortForwards: [String] = []
  
  @Argument(
    help: "name of the container"
  )
  var containerName: String
  
  @Argument(
    parsing: .unconditionalRemaining,
    help: .init(
      "If a <command> is specified, it is executed on the container instead of a login shell",
      valueName: "command"
    )
  )
  fileprivate var cmd: [String] = []
  
  var command: [String] {
    get {
      if cmd.first == "--" {
        return Array(cmd.dropFirst())
      } else {
        return cmd
      }
    }
  }

  func validate() throws {
    try validateContainerName(containerName)
  }
  
  func run() throws {
    let ip = try BuildCLIConfig.shared.machine(io: io).ip().awaitOutput()!
    let user = BuildCLIConfig.shared.sshUser
    let port = BuildCLIConfig.shared.sshPort
    var cmd = [
      "ssh", "-t",
      "-p", String(port)
      ]
    for b in localPortForwards {
      cmd.append("-L")
      cmd.append(b)
    }
    for b in reversePortForwards {
      cmd.append("-R")
      cmd.append(b)
    }
    if agent {
      cmd.append("-A")
    }
    if verboseOptions.verbose {
      cmd.append("-v")
    }
    
    cmd.append(contentsOf: ["\(user)@\(ip)", "--", containerName])
    cmd.append(contentsOf: command)
    
    cmd = cmd.filter { !$0.isEmpty }
    printDebug("Executing : `\(cmd.joined(separator: " "))`")
    let (argc, argv, _) = Argv.build(cmd)
    let code = blink_ssh_main(argc: argc, argv: argv)
    throw ArgumentParser.ExitCode(code)
  }
}

struct BuildMOSH: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "mosh",
    abstract: "MOSH to container"
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  @Argument(
    help: "name of the container"
  )
  var containerName: String
  
  func validate() throws {
    try validateContainerName(containerName)
  }
  
  func run() throws {
    let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
    let ip = try BuildCLIConfig.shared.machine(io: io).ip().awaitOutput()!
    print("Starting mosh connection...")
    let user = BuildCLIConfig.shared.sshUser
    let port = BuildCLIConfig.shared.sshPort
    session.cmdQueue.async {
      session.enqueueCommand("mosh -P \(port) \(user)@\(ip) \(containerName)", skipHistoryRecord: true)
    }
  }
}

struct BuildSSHCopyID: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "ssh-copy-id",
    abstract: "Add public key to build machine authorized_keys file"
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  @Option(
    name: .shortAndLong,
    help: "Idenity file"
  )
  var identity: String?


  func validate() throws {
    
  }
  
  func run() throws {
    printDebug("Searching for key in keychain...")
    if let key = BKPubKey.withID(identity)?.publicKey {
      printDebug("Key found in keychain")
      let _ = try BuildCLIConfig.shared.machine(io: io).sshKeys.add(sshKey: key).awaitOutput()
      print("Key is added.")
      return
    }
    
    printDebug("No key is found in keychain. Fallback to file system.")
    var keyPath = ""
    if let identity = identity {
      keyPath = identity.hasSuffix(".pub") ? keyPath : identity + ".pub"
    } else {
      keyPath = "~/.ssh/id_rsa.pub"
    }
    
    let path = keyPath.replacingOccurrences(of: "~", with: BlinkPaths.documents())
//    let path: String = NSString(string: keyPath).expandingTildeInPath
    
    printDebug("Reading key at path: \(path)")
    
    guard
      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    else {
      throw ValidationError("Can't read pub key at path: \(path)")
    }
    
    let _ = try BuildCLIConfig.shared.machine(io: io).sshKeys.add(sshKey: key).awaitOutput()
    print("Key is added.")
  }
}


@_cdecl("build_main")
public func build_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let io = NonStdIO.standart
  io.in_ = InputStream(file: thread_stdin)
  io.out = OutputStream(file: thread_stdout)
  io.err = OutputStream(file: thread_stderr)
  
  BuildCLIConfig.shared = BuildCLIConfig.blinkConfig
  
  BuildCommands.customSSHCommand = BuildSSH.self
  BuildCommands.customMOSHCommand = BuildMOSH.self
  BuildCommands.customSSHCopyCommand = BuildSSHCopyID.self
  ImageCommands.customImageBuildCommand = BuildImageBuildCommand.self
  
//  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
//  let rawMode = session.device.rawMode
//  defer {
//    session.device.rawMode = rawMode
//  }
//  session.device.rawMode = true
  
  return BuildCLI.BuildCommands.main(Array(argv.args(count: argc)[1...]), io: io)
}

