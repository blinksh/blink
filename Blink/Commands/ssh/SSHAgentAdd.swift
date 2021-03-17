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

import ArgumentParser
import SSH


struct BlinkSSHAgentAddCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Blink Agent Control",
    discussion: """
    """,
    version: "1.0.0"
  )
  
  // List
  @Flag(name: [.customShort("l")],
  help: "List keys stored on agent")
  var list: Bool = false
  
  // Remove
  @Flag(name: [.customShort("d")],
  help: "Remove key from agent")
  var remove: Bool = false
  
  @Argument(help: "Key name")
  var keyName: String
  
  @Argument(help: "Agent name")
  var agentName: String?
}

@_cdecl("blink_ssh_add")
public func blink_ssh_add(argc: Int32, argv: Argv) -> Int32 {
  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkSSHAgentAdd()
  session.registerSSHClient(cmd)
  let rc = cmd.start(argc, argv: argv.args(count: argc))
  session.unregisterSSHClient(cmd)

  return rc
}

public class BlinkSSHAgentAdd: NSObject {
  var command: BlinkSSHAgentAddCommand!
  
  var stdout = StdoutOutputStream()
  var stderr = StderrOutputStream()
  let currentRunLoop: RunLoop
  
  override init() {
    self.currentRunLoop = RunLoop.current
  }
  
  public func start(_ argc: Int32, argv: [String]) -> Int32 {
    do {
      command = try BlinkSSHAgentAddCommand.parse(Array(argv[1...]))
    } catch {
      let message = BlinkSSHAgentAddCommand.message(for: error)
      print(message, to: &stderr)
      return -1
    }
    
    if command.remove {
      if let _ = SSHAgentPool.removeKey(named: command.keyName) {
        print("Key \(command.keyName) removed.", to: &stdout)
        return 0
      } else {
        print("Key not found on Agent", to: &stderr)
        return -1
      }
    }
    
    if command.list {
      return 0
    }
    
    // TODO Can we have the same key under different constraints?
    
    // Default case: add key
    if let (blob, name) = BKConfig.privateKey(forIdentifier: command.keyName) {
      // TODO We should create a Keychain Signer instead of keeping it in memory
      guard let keyBlob = blob.data(using: .utf8),
            let key = try? SSHKey(fromFileBlob: keyBlob) else {
        print("Invalid key cannot be added to Agent.", to: &stderr)
        return -1
      }
      
      SSHAgentPool.addKey(key, named: name)
      print("Key \(name) - added to agent.", to: &stdout)
      return 0
    } else {
      print("Key not found", to: &stderr)
      return -1
    }
  }
}
