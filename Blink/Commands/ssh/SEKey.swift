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

import CryptoKit
import Foundation

import SSH

public enum KeychainError: Error {
  case unhandledError(status: OSStatus)
  
  public var description: String {
    switch self {
    case .unhandledError(let status):
      return "Keychain Error: \(message(status) ?? "Unknown")"
    }
  }

  private func message(_ status: OSStatus) -> String? {
    SecCopyErrorMessageString(status, nil) as String?
  }
}

public class SEKey: Signer {
  fileprivate static let type = kSecAttrKeyTypeECSECPrimeRandom
  fileprivate static let signatureType = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
  
  public var comment: String? { nil }
  public var sshKeyType: SSHKeyType { .ecdsa }
  
  let privateKey: SecKey
  public var publicKey: PublicKey { SEPublicKey(from: self)! }

  // Attributes can enable TouchID when using.
  // SE Only works with 256-bit elliptic curves
  // Tag should be unique and use domain format.
  static public func create(tagged tag: String, requireUserPresence: Bool = false) throws -> SEKey {
    var flags: SecAccessControlCreateFlags = [.privateKeyUsage]
    if requireUserPresence {
      flags.insert(.userPresence)
    }

    var accessError: Unmanaged<CFError>?
    guard let access =
      SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                      flags,
                                      &accessError) else {
      throw accessError!.takeRetainedValue() as Error
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String:            type,
      kSecAttrKeySizeInBits as String:      256,
      kSecAttrTokenID as String:            kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String:      true,
        kSecAttrApplicationTag as String:   tag,
        kSecAttrAccessControl as String:    access
      ]
    ]

    var error: Unmanaged<CFError>?
    guard
      SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil
    else {
      throw error!.takeRetainedValue() as Error
    }
    
    return SEKey(tagged: tag)!
  }
  
  static public func delete(tag: String) throws {
    let query = SEKey.keyQuery(withTag: tag)
    let status = SecItemDelete(query as CFDictionary)
    guard
      status == errSecSuccess || status == errSecItemNotFound
    else {
      throw KeychainError.unhandledError(status: status)
    }
  }

  init?(tagged tag: String) {
    let query = SEKey.keyQuery(withTag: tag)

    var item: CFTypeRef!
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard
      status == errSecSuccess,
      item != nil
    else {
      return nil
      
    }

    self.privateKey = item as! SecKey
  }

  public func sign(_ message: Data, algorithm: String?) throws -> Data {
    let derSignature = try signDER(message)

    // From Secretive
    // https://github.com/maxgoedjen/secretive/blob/f30d1f802f12a7779ffd03f075e74c58e223a5e5/SecretAgentKit/Agent.swift#L100
    // Convert from DER formatted rep to raw (r||s)
    let raw = try CryptoKit.P256.Signing.ECDSASignature(derRepresentation: derSignature).rawRepresentation
    let rawLength = raw.count / 2
    
    // Check if we need to pad with 0x00 to prevent certain
    // ssh servers from thinking r or s is negative
    let paddingRange: ClosedRange<UInt8> = 0x80...0xFF
    var r = Data(raw[0..<rawLength])
    if paddingRange ~= r.first! {
      r.insert(0x00, at: 0)
    }
    var s = Data(raw[rawLength...])
    if paddingRange ~= s.first! {
      s.insert(0x00, at: 0)
    }
    
    let signature = SSHEncode.data(from: r) + SSHEncode.data(from: s)
    let signatureChunk = SSHEncode.data(from: publicKey.type) + SSHEncode.data(from: signature)
    
    return signatureChunk
  }
  
  func signDER(_ message: Data) throws -> Data {
    var error: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(self.privateKey, SEKey.signatureType,
                                                message as CFData, &error) as Data?
    else {
      throw error!.takeRetainedValue()
    }
    return signature
  }
  
  private static func keyQuery(withTag tag: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecReturnRef as String: true
    ]
  }
}

public class SEPublicKey: PublicKey {
  public var type: String { "ecdsa-sha2-nistp256" }
  public var curveName: String { "nistp256" }
  
  let publicKey: SecKey
  
  fileprivate init?(from key: SEKey) {
    // This could return an optional, which we guess it would be a coding error (not passing a proper Private Key).
    // What we will do is enforce the "coding error" ourselves, as that should never happen.
    guard
      let publicKey = SecKeyCopyPublicKey(key.privateKey)
    else {
      return nil
    }
    self.publicKey = publicKey
  }

  // For the Agent interface, we don't need to verify. But it helps with the tests.
  public func verifyDER(signature bytes: Data, of data: Data) throws -> Bool {
    var error: Unmanaged<CFError>?
    
    let result = SecKeyVerifySignature(publicKey, SEKey.signatureType,
                               data as CFData, bytes as CFData, &error)
    if error != nil {
      throw error!.takeRetainedValue() as Error
    }
    
    return result
  }

  public func encode() throws -> Data {
    var error: Unmanaged<CFError>?
    // For ECDSA, this outputs the proper key point encoded as octet (04||X||Y)
    guard
      let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
    else {
      throw error!.takeRetainedValue() as Error
    }
    
    // Then we add the identifiers
    let blob = SSHEncode.data(from: type) +
      SSHEncode.data(from: curveName) +
      SSHEncode.data(from: data)
    
    // And on the wire, we still need the full size
    return SSHEncode.data(from: blob)
  }
}
