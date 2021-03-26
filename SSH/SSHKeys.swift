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
import System

import OpenSSH

fileprivate typealias psshkey = UnsafeMutablePointer<sshkey>
fileprivate typealias psshbuf = UnsafeMutablePointer<sshbuf>

public enum SSHKeyError: Error, LocalizedError {
  case general(title: String, rc: Int32? = nil)
  case wrongPassphrase
  
  public var errorDescription: String? {
    switch self {
    case .wrongPassphrase: return "Wrong passpharse"
    case .general(title: let title, rc: let rc):
      if let rc = rc  {
        return "\(title) \(String(cString: ssh_err(rc)))"
      }
      return "SSH Key Error - \(title)"
    }
  }
}

public enum SSHKeyType: Int32 {
  case rsa = 0
  case dsa
  case ecdsa
  case ed25519
  case rsaCert
  case dsaCert
  case ecdsaCert
  case ed25519Cert
  
  public var shortName: String {
    switch self {
    case .rsa: return "RSA"
    case .dsa: return "DSA"
    case .ecdsa: return "ECDSA"
    case .ed25519: return "ED25519"
    case .rsaCert: return "RSA-CERT"
    case .dsaCert: return "DSA-CERT"
    case .ecdsaCert: return "ECDSA-CERT"
    case .ed25519Cert: return "ED25519-CERT"
    }
  }
}


extension SSHKeyType {
  fileprivate init(for key: psshkey) throws {
    guard
      let type = SSHKeyType(rawValue: key.pointee.type)
    else {
      throw SSHKeyError.general(title: "Unsupported  key type \(sshkey_type(key))")
    }
    self = type
  }
}

public class SSHKey: Signer, PublicKey {
  fileprivate var pkey: psshkey
  var key: sshkey { pkey.pointee }
  // Store the type as a way to limit what types of keys we support
  fileprivate var keyType: SSHKeyType
  fileprivate var pcomment: UnsafeMutablePointer<CChar>?
  public var comment: String? {
    if let p = pcomment {
      return String(cString: p)
    } else {
      return nil
    }
  }

  public var publicKey: PublicKey { get { self } }
  public var type: String { get { String(cString: sshkey_ssh_name(pkey)) } }
  public var sshKeyType: SSHKeyType { get { keyType } }

  convenience public init(
    fromFile privateKeyPath: String,
    passphrase: String = "",
    withPublicFileCert publicCertPath: String? = nil
  ) throws {
    let f = try FileDescriptor.open(privateKeyPath, .readOnly)
    defer {
      try? f.close()
    }
    var blob: psshbuf! = nil
    guard
      sshbuf_load_fd(f.rawValue, &blob) == 0,
      blob != nil
    else {
      throw SSHKeyError.general(title: "Could not load key blob")
    }
    defer {
      sshbuf_free(blob)
    }

    try self.init(fileBlob: blob, passphrase: passphrase)

    if let publicCertPath = publicCertPath {
      var pubkey: psshkey!
      let rc = sshkey_load_public(publicCertPath, &pubkey, &pcomment)
      guard rc == 0, pubkey != nil else {
        throw SSHKeyError.general(title: "Error parsing certificate file.", rc: rc)
      }
      defer {
        sshkey_free(pubkey)
      }
      
      if sshkey_equal_public(self.pkey, pubkey) == 0 {
        throw SSHKeyError.general(title: "Key does not match certificate")
      }
      
      // NOTE They need to be tied to each other. We cannot just separate in our structure.
      if sshkey_to_certified(self.pkey) != 0 || sshkey_cert_copy(pubkey, self.pkey) != 0 {
        throw SSHKeyError.general(title: "Error processing certificate")
      }
    }
  }

  // Both private and public key blobs must be cleaned up and properly formatted.
  convenience public init(
    fromFileBlob privateKey: Data,
    passphrase: String = "",
    withPublicFileCertBlob publicCert: Data? = nil
  ) throws {
    // We need to retain Data as the key object is empty

    let b: psshbuf? = privateKey.withUnsafeBytes {
      sshbuf_from($0.baseAddress, $0.count)
    }
    guard let blob = b else {
      throw SSHKeyError.general(title: "Could not initiate buffer")
    }
    defer {
      sshbuf_free(blob)
    }

    try self.init(fileBlob: blob, passphrase: passphrase)

    if var publicCert = publicCert {
      // Unlike the private case, there is no function to read a public key from a file blob.
      // OpenSSH performs some cleanup, we will assume data has been cleaned beforehand.
      guard let pubkey = sshkey_new(Int32(KEY_UNSPEC.rawValue)) else {
        throw SSHKeyError.general(title: "Could not initiate key")
      }
      defer {
        sshkey_free(pubkey)
      }
      let rc: Int32 = publicCert.withUnsafeMutableBytes { buffer in
        var b = buffer.baseAddress?.assumingMemoryBound(to: CChar.self)
        return sshkey_read(pubkey, &b)
      }
      guard rc == 0 else {
        throw SSHKeyError.general(title: "Error parsing public key.", rc: rc)
      }
      
      if sshkey_equal_public(self.pkey, pubkey) == 0 {
        throw SSHKeyError.general(title: "Key does not match certificate")
      }
      
      if sshkey_to_certified(self.pkey) != 0 || sshkey_cert_copy(pubkey, self.pkey) != 0 {
        throw SSHKeyError.general(title: "Error processing certificate")
      }
    }
  }

  fileprivate init(fileBlob blob: psshbuf, passphrase: String = "") throws {
    var pkey: psshkey!

    let rc = sshkey_parse_private_fileblob(blob, passphrase, &pkey, &self.pcomment)
    
    if rc == SSH_ERR_KEY_WRONG_PASSPHRASE {
      throw SSHKeyError.wrongPassphrase
    }

    guard rc == 0, pkey != nil else {
      throw SSHKeyError.general(title: "Error parsing private key.", rc: rc)
    }
    self.pkey = pkey
    self.keyType = try SSHKeyType(for: pkey)
  }

  // Wire public representation for key
  public init(fromPublicBlob data: Data) throws {
    var pkey: psshkey!
    let rc: Int32 = data.withUnsafeBytes { buffer in
      let p = buffer.baseAddress?.assumingMemoryBound(to: u_char.self)
      return sshkey_from_blob(p, buffer.count, &pkey)
    }
    guard rc == 0, pkey != nil else {
      throw SSHKeyError.general(title: "Error parsing public key.", rc: rc)
    }
    self.pkey = pkey
    self.keyType = try SSHKeyType(for: pkey)
  }

  public init(fromPublicKeyFile path: String) throws {
    var pkey: psshkey!

    // NOTE There is no function to read the file as a blob on OpenSSH.
    let rc = sshkey_load_public(path, &pkey, &pcomment)
    guard rc == 0, pkey != nil else {
      throw SSHKeyError.general(title: "Error parsing public key file.", rc: rc)
    }
    self.pkey = pkey
    self.keyType = try SSHKeyType(for: pkey)
  }

  public init(type: SSHKeyType, bits: UInt32) throws {
    var pkey: psshkey!

    let rc = sshkey_generate(type.rawValue, bits, &pkey)
    guard rc == 0, pkey != nil else {
      throw SSHKeyError.general(title: "Error generating key.", rc: rc)
    }
    self.pkey = pkey
    self.keyType = type
  }

  public func sign(_ message: Data, algorithm: String? = nil) throws -> Data {
    // This function follows sshsig_wrap_sign on OpenSSH.
    var pSig: UnsafeMutablePointer<CUnsignedChar>? = nil
    var sigLen: Int = 0

    let rc: Int32 = message.withUnsafeBytes { buffer in
      let p = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
      return sshkey_sign(pkey, &pSig, &sigLen, p, buffer.count, algorithm, nil, nil, 0)
    }
    
    guard rc == 0 else {
      throw SSHKeyError.general(title: "Couldn't sign message", rc: rc)
    }

    // The signature is an ssh signature already, with the p and s parameters set, etc...
    let sig = Data(bytes: pSig!, count: sigLen)
    pSig?.deallocate()

    return sig
  }

  public func verify(signature bytes: Data, of data: Data) throws -> Bool {
    let rc: Int32 = bytes.withUnsafeBytes { buffer in
      let b = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)

      return data.withUnsafeBytes { data in
        let d = data.baseAddress?.assumingMemoryBound(to: UInt8.self)
        return sshkey_verify(pkey, b, bytes.count, d, data.count, nil, 0, nil)
      }
    }
    
    // ssh_key_verify returns 0 for a correct signature  and < 0 on error.
    if rc < 0 {
      throw SSHKeyError.general(title: "Signature Verification failed", rc: rc)
    }

    return true
  }
 
  public func encode() throws -> Data {
    // Based on process_request_identities
    guard
      let blob = sshbuf_new()
    else {
      throw SSHKeyError.general(title: "Could not create buffer blob for key")
    }
    
    defer {
      sshbuf_free(blob)
    }

    let rc = sshkey_puts_opts(pkey, blob, SSHKEY_SERIALIZE_INFO)
    guard rc == 0 else {
      throw SSHKeyError.general(title: "Could not encode key.", rc: rc)
    }

    return Data(bytes: sshbuf_ptr(blob), count: sshbuf_len(blob))
  }
  
  public func privateKeyFileBlob(comment: String? = nil, passphrase: String? = nil) throws -> Data {
    // We could add PEM or PKCS8 for certs
    let format = SSHKEY_PRIVATE_OPENSSH
    
    guard
      let blob = sshbuf_new()
    else {
      throw SSHKeyError.general(title: "Could not create buffer blob.")
    }
    defer {
      sshbuf_free(blob)
    }
    
    // No special cipher and no rounds
    let rc = sshkey_private_to_fileblob(pkey, blob, passphrase, comment, Int32(format.rawValue), nil, 0)
    guard rc == 0 else {
      throw SSHKeyError.general(title: "Error exporting private key to file blob", rc: rc)
    }
    
    return Data(bytes: sshbuf_ptr(blob), count: sshbuf_len(blob))
  }
  
  deinit {
    sshkey_free(pkey)
    pcomment?.deallocate()
  }
}

extension SSHKey {
  // Method to cleanup a key, useful when received from a clipboard or a potentially malformed source.
  // Makes sure first character will be a dash.
  // Makes sure the final character is a newline.
  public static func sanitize(key str: String) -> String {
    var key = str
    if let r = key.range(of: "-----BEGIN") {
      key.removeSubrange(..<r.lowerBound)
    }

    if let fr = key.range(of: "-----", options: .backwards, range: nil, locale: nil) {
      key.replaceSubrange(fr.upperBound..., with: "\n")
    }
    
    key = key.replacingOccurrences(of: "(?m)^\\s+", with: "", options: .regularExpression)
    return key
  }
}
