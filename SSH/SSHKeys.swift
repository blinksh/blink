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

public struct SSHKeyError: Error {
  let msg: String

  init(_ rc: Int32, title: String) {
    self.msg = "\(title) \(String(cString: ssh_err(rc)))"
  }
  init(title: String) {
    self.msg = "SSH Key Error - \(title)"
  }
}

public enum SSHKeyType: Int32 {
  case KEY_RSA = 0
  case KEY_DSA
  case KEY_ECDSA
  case KEY_ED25519
  case KEY_RSA_CERT
  case KEY_DSA_CERT
  case KEY_ECDSA_CERT
  case KEY_ED25519_CERT
}

extension SSHKeyType {
  fileprivate init(for key: psshkey) throws {
    guard
      let type = SSHKeyType(rawValue: key.pointee.type)
    else {
      throw SSHKeyError(title: "Unsupported  key type \(sshkey_type(key))")
    }
    self = type
  }
}

public class SSHKey: Signer, PublicKey {
  public typealias SSHKeyPassphraseReader = () -> String?
  
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
    withPublicFileCert publicCertPath: String? = nil,
    passphraseReader: SSHKeyPassphraseReader = { nil }
  ) throws {
    let f = try FileDescriptor.open(privateKeyPath, .readOnly)
    var blob: psshbuf? = nil
    defer {
      sshbuf_free(blob)
      try? f.close()
    }
    let rc = sshbuf_load_fd(f.rawValue, &blob)
    if rc != 0 {
      throw SSHKeyError(title: "Could not load key blob")
    }

    try self.init(fileBlob: blob!, passphraseReader: passphraseReader)

    if let publicCertPath = publicCertPath {
      var pubkey: psshkey?
      let rc = sshkey_load_public(publicCertPath, &pubkey, &pcomment)
      if rc != 0 {
        throw SSHKeyError(rc, title: "Error parsing certificate file.")
      }
      
      if sshkey_equal_public(self.pkey, pubkey) == 0 {
        throw SSHKeyError(title: "Key does not match certificate")
      }
      
      // NOTE They need to be tied to each other. We cannot just separate in our structure.
      if sshkey_to_certified(self.pkey) != 0 || sshkey_cert_copy(pubkey, self.pkey) != 0 {
        throw SSHKeyError(title: "Error processing certificate")
      }
      sshkey_free(pubkey)
    }
  }

  // Both private and public key blobs must be cleaned up and properly formatted.
  convenience public init(
    fromFileBlob privateKey: Data,
    withPublicFileCertBlob publicCert: Data? = nil,
    passphraseReader: SSHKeyPassphraseReader = { nil }
  ) throws {
    // We need to retain Data as the key object is empty
    var blob: psshbuf? = nil

    try privateKey.withUnsafeBytes { bytes in
      guard let b = sshbuf_from(bytes.baseAddress, privateKey.count) else {
        throw SSHKeyError(title: "Could not initiate buffer")
      }
      blob = b
    }

    try self.init(fileBlob: blob!, passphraseReader: passphraseReader)

    if publicCert != nil {
      // Unlike the private case, there is no function to read a public key from a file blob.
      // OpenSSH performs some cleanup, we will assume data has been cleaned beforehand.
      let pubkey = sshkey_new(Int32(KEY_UNSPEC.rawValue))
      var publicCert = publicCert
      try publicCert?.withUnsafeMutableBytes { buffer in
        var b = buffer.baseAddress?.assumingMemoryBound(to: Int8.self)
        let rc = sshkey_read(pubkey, &b)
        if rc != 0 {
          sshbuf_free(blob)
          sshkey_free(pubkey)
          throw SSHKeyError(rc, title: "Error parsing public key.")
        }
      }
      
      if sshkey_equal_public(self.pkey, pubkey) == 0 {
        throw SSHKeyError(title: "Key does not match certificate")
      }
      
      if sshkey_to_certified(self.pkey) != 0 || sshkey_cert_copy(pubkey, self.pkey) != 0 {
        throw SSHKeyError(title: "Error processing certificate")
      }
      sshkey_free(pubkey)
    }

    // NOTE If deferring, it will crash with segfault. Cannot explain.
    sshbuf_free(blob)
  }

  fileprivate init(fileBlob blob: psshbuf, passphraseReader: SSHKeyPassphraseReader = { nil }) throws {
    var pkey: psshkey?

    let emptyPassphrase = ""
    var rc = sshkey_parse_private_fileblob(blob, emptyPassphrase, &pkey, &self.pcomment)
    while rc == SSH_ERR_KEY_WRONG_PASSPHRASE {
      guard
        let passphrase = passphraseReader()
      else {
        sshbuf_free(blob)
        throw SSHKeyError(rc, title: "Wrong passphrase.")
      }
      rc = sshkey_parse_private_fileblob(blob, passphrase, &pkey, &self.pcomment)
    }
    if rc != 0 || pkey == nil {
      sshbuf_free(blob)
      throw SSHKeyError(rc, title: "Error parsing private key.")
    }
    self.pkey = pkey!
    self.keyType = try SSHKeyType(for: pkey!)
  }

  // Wire public representation for key
  public init(fromPublicBlob data: Data) throws {
    let length = data.count
    var pkey: psshkey?
    try data.withUnsafeBytes { buffer in
      let p: UnsafePointer<u_char>? = buffer.baseAddress!.assumingMemoryBound(to: u_char.self)
      let rc = sshkey_from_blob(p, length, &pkey)
      if rc != 0 || pkey == nil {
        throw SSHKeyError(rc, title: "Error parsing public key.")
      }
    }
    self.pkey = pkey!
    self.keyType = try SSHKeyType(for: pkey!)
  }

  public init(fromPublicKeyFile path: String) throws {
    var pkey: psshkey?

    // NOTE There is no function to read the file as a blob on OpenSSH.
    let rc = sshkey_load_public(path, &pkey, &pcomment)
    if rc != 0 {
      throw SSHKeyError(rc, title: "Error parsing public key file.")
    }
    self.pkey = pkey!
    self.keyType = try SSHKeyType(for: pkey!)
  }

  public init(type: SSHKeyType, bits: UInt32) throws {
    var pkey: psshkey?

    let rc = sshkey_generate(type.rawValue, bits, &pkey)
    if rc != 0 || pkey == nil {
      throw SSHKeyError(rc, title: "Error generating key.")
    }
    self.pkey = pkey!
    self.keyType = type
  }

  public func sign(_ message: Data, algorithm: String? = nil) throws -> Data {
    // This function follows sshsig_wrap_sign on OpenSSH.
    var pSig: UnsafeMutablePointer<CUnsignedChar>? = nil
    var sigLen: Int = 0

    try message.withUnsafeBytes { buffer in
      let p: UnsafePointer<UInt8>? = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
      let rc = sshkey_sign(pkey, &pSig, &sigLen, p, message.count, algorithm, nil, nil, 0)
      if rc != 0 {
        throw SSHKeyError(rc, title: "Couldn't sign message")
      }
    }

    // The signature is an ssh signature already, with the p and s parameters set, etc...
    let sig = Data(bytes: pSig!, count: sigLen)
    pSig?.deallocate()

    return sig
  }

  public func verify(signature bytes: Data, of data: Data) throws -> Bool {
    try bytes.withUnsafeBytes { buffer in
      let b: UnsafePointer<UInt8>? = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)

      try data.withUnsafeBytes { data in
        let d: UnsafePointer<UInt8>? = data.baseAddress!.assumingMemoryBound(to: UInt8.self)
        let rc = sshkey_verify(pkey, b, bytes.count, d, data.count, nil, 0, nil)
        if rc < 0 {
          throw SSHKeyError(rc, title: "Signature Verification failed")
        }
      }
    }

    return true
  }
 
  public func encode() throws -> Data {
    // Based on process_request_identities
    guard let blob = sshbuf_new() else {
      throw SSHKeyError(title: "Could not create buffer blob for key")
    }

    let rc = sshkey_puts_opts(pkey, blob, SSHKEY_SERIALIZE_INFO)
    if rc != 0 {
      throw SSHKeyError(rc, title: "Could not encode key.")
    }

    let d = Data(bytes: sshbuf_ptr(blob), count: sshbuf_len(blob))
    sshbuf_free(blob)

    return d
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
