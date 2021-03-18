//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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
import LibSSH
import OpenSSH


public enum SSHAgentMessageType: UInt8 {
  case failure = 5
  case success = 6
  case requestIdentities = 11
  case answerIdentities = 12
  case requestSignature = 13
  case responseSignature = 14
}

fileprivate let errorData = Data(bytes: [0x05], count: MemoryLayout<CChar>.size)

public class SSHAgentKey {
  let constraints: [SSHAgentConstraint]?
//  var expiration: Int
  let signer: Signer
  let name: String
  
  init(_ key: Signer, named: String, constraints: [SSHAgentConstraint]? = nil) {
    self.signer = key
    self.name = named
    self.constraints = constraints
  }
}

public class SSHAgent {
  public private(set) var ring: [SSHAgentKey] = []
  // NOTE Instead of the Agent tracking the constraints, we could have a delegate for that.
  // NOTE The Agent name won't be relevant when doing Jumps between hosts, but at least you will know the first originator.

  public init() {}

  private var contexts: [AgentCtxt] = []
  private class AgentCtxt {
    let agent: SSHAgent
    weak var client: SSHClient?
    
    init(agent: SSHAgent, client: SSHClient) {
      self.agent = agent
      self.client = client
    }
  }

  public func attachTo(client: SSHClient) {
    let agentCtxt = AgentCtxt(agent: self, client: client)
    contexts.append(agentCtxt)
    let ctxt = UnsafeMutableRawPointer(Unmanaged.passUnretained(agentCtxt).toOpaque())
    let cb: ssh_agent_callback = { (req, len, reply, userdata) in
      // Transform to Swift types and call the request.
      let ctxt = Unmanaged<AgentCtxt>.fromOpaque(userdata!).takeUnretainedValue()
      var payload = Data(bytesNoCopy: req!, count: Int(len), deallocator: .none)
      let typeValue = SSHDecode.uint8(&payload)

      var replyData: Data
      let replyLength: Int
      // Fix types. Cannot be nil as the callback is called by the client
      guard let client = ctxt.client else {
        return 0
      }
      if let type = SSHAgentMessageType(rawValue: typeValue) {
        replyData = ctxt.agent.request(payload, context: type, client: client)
        replyLength = replyData.count
      } else {
        // Return error if type is unknown
        replyData = errorData
        replyLength = errorData.count
      }

      _ = replyData.withUnsafeMutableBytes { ptr in
        ssh_buffer_add_data(reply, ptr.baseAddress!, UInt32(replyLength))
      }

      return Int32(replyData.count)
    }
    
    ssh_set_agent_callback(client.session, cb, ctxt)
  }

  public func loadKey(_ key: Signer, aka name: String, constraints: [SSHAgentConstraint]? = nil) {
    let cKey = SSHAgentKey(key, named: name, constraints: constraints)
    ring.append(cKey)
  }

  func request(_ message: Data, context: SSHAgentMessageType, client: SSHClient) -> Data {
    do {
      switch context {
      case .requestIdentities:
        return try encodedRing()
      case .requestSignature:
        return try sign(message, for: client)
      default:
        throw SSHKeyError.general(title: "Invalid request received")
      }
    } catch {
      // TODO Log error
      return errorData
    }
  }

  func encodedRing() throws -> Data {
    var respType = SSHAgentMessageType.answerIdentities.rawValue

    var keys: UInt32 = UInt32(ring.count).bigEndian
    var preamble = Data(bytes: &respType, count: MemoryLayout<CChar>.size)
    preamble.append(Data(bytes: &keys, count: MemoryLayout<UInt32>.size))

    return try ring.map { (try $0.signer.publicKey.encode()) + SSHEncode.data(from: $0.signer.comment ?? "") }
      .reduce(preamble) { (res, val) in
        var data = res
        data.append(val)
        return data
      }
  }

  func sign(_ message: Data, for client: SSHClient) throws -> Data {
    var respType = SSHAgentMessageType.responseSignature.rawValue

    var msg = message
    let keyBlob = SSHDecode.bytes(&msg)
    let data = SSHDecode.bytes(&msg)
    let flags = SSHDecode.uint32(&msg)

    guard let key = lookupKey(blob: keyBlob) else {
      throw SSHKeyError.general(title: "Could not find proposed key")
    }
    let algorithm: String? = SigDecodingAlgorithm(rawValue: Int8(flags)).algorithm(for: key.signer)

    // Enforce constraints
    try key.constraints?.forEach {
      if !$0.enforce(useOf: key, by: client) { throw SSHKeyError.general(title: "Denied operation by constraint: \($0.name).") }
    }

    let signature = try key.signer.sign(data, algorithm: algorithm)
    // Wire format signature
    var sigLength: UInt32 = UInt32(signature.count).bigEndian
    var sigString = Data(bytes: &sigLength, count: MemoryLayout<UInt32>.size)
    sigString.append(signature)

    var d = Data(bytes: &respType, count: MemoryLayout<CChar>.size)
    d.append(sigString)

    return d
  }

  fileprivate func lookupKey(blob: Data) -> SSHAgentKey? {
    // Get rid of the blob size from encode before comparing.
    ring.first { (try? $0.signer.publicKey.encode()[4...]) == blob }
  }
}

fileprivate struct SigDecodingAlgorithm: OptionSet {
  public let rawValue: Int8
  public init(rawValue: Int8) {
    self.rawValue = rawValue
  }

  public static let RsaSha2256 = SigDecodingAlgorithm(rawValue: 1 << 1)
  public static let RsaSha2512 = SigDecodingAlgorithm(rawValue: 1 << 2)

  func algorithm(for key: Signer) -> String? {
    let type = key.sshKeyType

    if type == .KEY_RSA {
      if self.contains(.RsaSha2256) {
        return "rsa-sha2-256"
      } else if self.contains(.RsaSha2512) {
        return "rsa-sha2-512"
      }
    } else if type == .KEY_RSA_CERT {
      if self.contains(.RsaSha2256) {
        return "rsa-sha2-256-cert-v01@openssh.com"
      } else if self.contains(.RsaSha2512) {
        return "rsa-sha2-512-cert-v01@openssh.com"
      }
    }
    return nil
  }
}

public enum SSHEncode {
  public static func data(from str: String) -> Data {
    self.data(from: UInt32(str.count)) + (str.data(using: .utf8) ?? Data())
  }
  
  public static func data(from int: UInt32) -> Data {
    var length: UInt32 = UInt32(int).bigEndian
    return Data(bytes: &length, count: MemoryLayout<UInt32>.size)
  }
  
  public static func data(from bytes: Data) -> Data {
    self.data(from: UInt32(bytes.count)) + bytes
  }
}

public enum SSHDecode {
  static func string(_ bytes: inout Data) -> String? {
    let length = SSHDecode.uint32(&bytes)
    guard let str = String(data: bytes[0..<length], encoding: .utf8) else {
      return nil
    }
    bytes = bytes.advanced(by: Int(length))
    return str
  }

  static func bytes(_ bytes: inout Data) -> Data {
    let length = SSHDecode.uint32(&bytes)
    let d = bytes.subdata(in: 0..<Int(length))
    bytes = bytes.advanced(by: Int(length))
    return d
  }

  static func uint8(_ bytes: inout Data) -> UInt8 {
    let length = MemoryLayout<UInt8>.size
    let d = bytes.subdata(in: 0..<length)
    let value = UInt8(bigEndian: d.withUnsafeBytes { ptr in
      ptr.load(as: UInt8.self)
    })

    if bytes.count == Int(length) {
      bytes = Data()
    } else {
      bytes = bytes.advanced(by: Int(length))
    }
    return value
  }

  static func uint32(_ bytes: inout Data) -> UInt32 {
    let length = MemoryLayout<UInt32>.size
    let d = bytes.subdata(in: 0..<Int(length))
    let value = UInt32(bigEndian: d.withUnsafeBytes { ptr in
      ptr.load(as: UInt32.self)
    })

    if bytes.count == Int(length) {
      bytes = Data()
    } else {
      bytes = bytes.advanced(by: Int(length))
    }
    return value
  }
}
