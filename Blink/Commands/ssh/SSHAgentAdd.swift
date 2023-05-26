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
  
  @Flag(name: [.customShort("L")],
  help: "List keys stored on agent")
  var list: Bool = false
  
  @Flag(name: [.customShort("l")],
  help: "Lists fingerprints of keys stored on agent")
  var listFingerprints: Bool = false
  
  // Remove
  @Flag(name: [.customShort("d")],
  help: "Remove key from agent")
  var remove: Bool = false
  
  // Hash algorithm
  @Option(
    name: [.customShort("E")],
    help: "Specify hash algorithm used for fingerprints"
  )
  var hashAlgorithm: String = "sha256"
  
  @Flag(name: [.customShort("c")],
        help: "Confirm before using identity"
  )
  var askConfirmation: Bool = false

  @Argument(help: "Key name")
  var keyName: String?
  
  @Argument(help: "Agent name")
  var agentName: String?
}

@_cdecl("blink_ssh_add")
public func blink_ssh_add(argc: Int32, argv: Argv) -> Int32 {
  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  let cmd = BlinkSSHAgentAdd()
  session.registerSSHClient(cmd)
  let rc = cmd.start(argc, argv: argv.args(count: argc), session: session)
  session.unregisterSSHClient(cmd)

  return rc
}

public class BlinkSSHAgentAdd: NSObject {
  var command: BlinkSSHAgentAddCommand!
  
  var stdout = OutputStream(file: thread_stdout)
  var stderr = OutputStream(file: thread_stderr)
  let currentRunLoop = RunLoop.current
  
  public func start(_ argc: Int32, argv: [String], session: MCPSession) -> Int32 {
    let bkConfig: BKConfig
    do {
      bkConfig = try BKConfig()
      command = try BlinkSSHAgentAddCommand.parse(Array(argv[1...]))
    } catch {
      let message = BlinkSSHAgentAddCommand.message(for: error)
      print(message, to: &stderr)
      return -1
    }
    
    if command.remove {
      let keyName = command.keyName ?? "id_rsa"
      if let _ = SSHAgentPool.removeKey(named: keyName) {
        print("Key \(keyName) removed.", to: &stdout)
        return 0
      } else {
        print("Key not found on Agent", to: &stderr)
        return -1
      }
    }
    
    if command.list {
      for key in SSHAgentPool.get()?.ring ?? []  {
        let str = BKPubKey.withID(key.name)?.publicKey ?? ""
        print("\(str) \(key.name)", to: &stdout)
      }
      
      return 0;
    }
    
    if command.listFingerprints {
      guard
        let alg = SSHDigest(rawValue: command.hashAlgorithm)
      else {
        print("Invalid hash algorithm \"\(command.hashAlgorithm)\"", to: &stderr)
        return -1;
      }
      
      for key in SSHAgentPool.get()?.ring ?? [] {
        if let blob = try? key.signer.publicKey.encode()[4...],
           let sshkey = try? SSHKey(fromPublicBlob: blob)
        {
          let str = sshkey.fingerprint(digest: alg)
          
          print("\(sshkey.size) \(str) \(key.name) (\(sshkey.sshKeyType.shortName))", to: &stdout)
        }
      }
      return 0
    }
    
    // TODO Can we have the same key under different constraints?
    
    // Default case: add key
    if let (signer, name) = bkConfig.signer(forIdentity: command.keyName ?? "id_rsa") {
      if let signer = signer as? BlinkConfig.InputPrompter {
        signer.setPromptOnView(session.device.view)
      }
      var constraints: [SSHAgentConstraint]? = nil
      if command.askConfirmation {
        constraints = [SSHAgentUserPrompt()]
      }
      
      SSHAgentPool.addKey(signer, named: name, constraints: constraints)
      print("Key \(name) - added to agent.", to: &stdout)
      return 0
    } else {
      print("Key not found", to: &stderr)
      return -1
    }
  }
}
