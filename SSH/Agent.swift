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

import Combine
import Dispatch
import Foundation
import LibSSH
import OpenSSH

public protocol PublicKey {
  // We may need this one for the Authorized key format
  var type: SSHKeyType { get }
  func encode() throws -> Data
  func verify(signature bytes: Data, of data: Data) throws -> Bool
  func equals(_ blob: Data) -> Bool
}

public protocol Signer {
  var publicKey: PublicKey { get }
  func sign(_ message: Data, algorithm: String?) throws -> Data
}

public enum SSHAgentMessageType: UInt8 {
  case failure = 5
  case success = 6
  case requestIdentities = 11
  case answerIdentities = 12
  case requestSignature = 13
  case responseSignature = 14
}

fileprivate let errorData = Data(bytes: [0x05], count: MemoryLayout<CChar>.size)

public enum SSHAgentConstraint {
  case confirm
  case lifetime
}

public class SSHAgentKey {
//  let constraints: [SSHAgentConstraint]
//  var expiration: Int
  let signer: Signer
  let name: String
  
  init(_ key: Signer, named: String) {
    self.signer = key
    self.name = named
  }
}

public class SSHAgent {
  public private(set) var ring: [SSHAgentKey] = []
  // 
  var trustConnection = false
  // NOTE Instead of the Agent tracking the constraints, we could have a delegate for that.
  // NOTE The Agent name won't be relevant when doing Jumps between hosts, but at least you will know the first originator.
  
  public var constraintsPublisher: ((_ keyName: String) -> AnyPublisher<InteractiveResponse, Error>)?
  
  public init() {}
    
  public func attachTo(client: SSHClient) {
    let ctxt = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    let cb: ssh_agent_callback = { (req, len, reply, userdata) in
      // Transform to Swift types and call the request.
      let ctxt = Unmanaged<SSHAgent>.fromOpaque(userdata!).takeUnretainedValue()
      var payload = Data(bytesNoCopy: req!, count: Int(len), deallocator: .none) // req!.advanced(by: 0)//by: MemoryLayout<UInt32>.size)
      let typeValue = ctxt.sshU8(&payload)

      var replyData: Data
      let replyLength: Int
      if let type = SSHAgentMessageType(rawValue: typeValue) {
        replyData = ctxt.request(payload, context: type)
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

  public func loadKey(_ key: Signer, aka name: String) {
    let cKey = SSHAgentKey(key, named: name)
    ring.append(cKey)
  }

  func request(_ message: Data, context: SSHAgentMessageType) -> Data {
    do {
      switch context {
      case .requestIdentities:
        return try encodedRing()
      case .requestSignature:
        return try sign(message)
      default:
        throw SSHKeyError(title: "Invalid request received")
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

    return try ring.map { try $0.signer.publicKey.encode() }
      .reduce(preamble) { (res, val) in
        var data = res
        data.append(val)
        return data
      }
  }

  func sign(_ message: Data) throws -> Data {
    var respType = SSHAgentMessageType.responseSignature.rawValue

    var msg = message
    let keyBlob = sshData(&msg)
    let data = sshData(&msg)
    let flags = sshU32(&msg)

    guard let key = lookupKey(blob: keyBlob) else {
      throw SSHKeyError(title: "Could not find proposed key")
    }
    let algorithm: String? = SigDecodingAlgorithm(rawValue: Int8(flags)).algorithm(for: key.signer)

    let response: InteractiveResponse = try await {
      if trustConnection {
        return .just(.affirmative)
      }
      
      guard let pub = constraintsPublisher else {
        return .just(.negative)
      }

      return pub(key.name)
    }

    if response == .negative {
      throw SSHKeyError(title: "User denied operation")
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
    // NOTE LibSSH reencodes the accepted public key, so we cannot depend on the bytes.
    ring.first { $0.signer.publicKey.equals(blob) }
  }

  fileprivate func sshString(_ bytes: inout Data) -> String? {
    let length = sshU32(&bytes)
    guard let str = String(data: bytes[0..<length], encoding: .utf8) else {
      return nil
    }
    bytes = bytes.advanced(by: Int(length))
    return str
  }

  fileprivate func sshData(_ bytes: inout Data) -> Data {
    let length = sshU32(&bytes)
    let d = bytes.subdata(in: 0..<Int(length))
    bytes = bytes.advanced(by: Int(length))
    return d
  }

  fileprivate func sshU8(_ bytes: inout Data) -> UInt8 {
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

  fileprivate func sshU32(_ bytes: inout Data) -> UInt32 {
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

fileprivate struct SigDecodingAlgorithm: OptionSet {
  public let rawValue: Int8
  public init(rawValue: Int8) {
    self.rawValue = rawValue
  }

  public static let RsaSha2256 = SigDecodingAlgorithm(rawValue: 1 << 1)
  public static let RsaSha2512 = SigDecodingAlgorithm(rawValue: 1 << 2)

  func algorithm(for key: Signer) -> String? {
    let type = key.publicKey.type

    if type.rawValue == KEY_RSA.rawValue {
      if self.contains(.RsaSha2256) {
        return "rsa-sha2-256"
      } else {
        return "rsa-sha2-512"
      }
    } else if type.rawValue == KEY_RSA_CERT.rawValue {
      if self.contains(.RsaSha2256) {
        return "rsa-sha2-256-cert-v01@openssh.com"
      } else {
        return "rsa-sha2-512-cert-v01@openssh.com"
      }
    }
    return nil
  }
}

fileprivate func await<U>(_ call: ()->(AnyPublisher<U, Error>)) throws -> U {
  let semaphore = DispatchSemaphore(value: 0)
  var val: U?

  let _ = call().sink(receiveCompletion: { _ in semaphore.signal() },
            receiveValue: { val = $0 })

  _ = semaphore.wait(wallTimeout: .distantFuture)
  
  guard let response = val else {
    throw SSHKeyError(title: "Error executing async callback")
  }
  
  return response
}

