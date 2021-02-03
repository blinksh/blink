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
    guard let type = SSHKeyType(rawValue: key.pointee.type) else {
      throw SSHKeyError(title: "Unsupported  key type \(sshkey_type(key))")
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
  var comment: String? {
    if let p = pcomment {
      return String(cString: p)
    } else {
      return nil
    }
  }

  public var publicKey: PublicKey { get { self } }
  public var type: SSHKeyType { get { keyType  } }

  convenience public init(fromFile path: String) throws {
    let f = try FileDescriptor.open(path, .readOnly)
    var blob: psshbuf? = nil
    defer {
      sshbuf_free(blob)
      try? f.close()
    }
    let rc = sshbuf_load_fd(f.rawValue, &blob)
    if rc != 0 {
      throw SSHKeyError(title: "Could not load key blob")
    }

    // TODO Passphrase. We may not need an async flow for it.
    try self.init(blob: blob!)
  }

  convenience public init(fromBlob data: Data) throws {
    // We need to retain Data as the key object is empty
    var blob: psshbuf? = nil

    try data.withUnsafeBytes { bytes in
      guard let b = sshbuf_from(bytes.baseAddress, data.count) else {
        throw SSHKeyError(title: "Could not initiate buffer")
      }
      blob = b
    }

    try self.init(blob: blob!)

    // NOTE If deferring, it will crash with segfault. Cannot explain.
    sshbuf_free(blob)
  }

  fileprivate init(blob: psshbuf) throws {
    // TODO Passphrases
    var pkey: psshkey?

    let rc = sshkey_parse_private_fileblob(blob, "", &pkey, &self.pcomment)
    if (rc != 0 && rc != SSH_ERR_KEY_WRONG_PASSPHRASE) || pkey == nil {
      sshbuf_free(blob)
      throw SSHKeyError(rc, title: "Error parsing private key.")
    }
    self.pkey = pkey!
    self.keyType = try SSHKeyType(for: pkey!)
  }

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
    var sig = Data(bytes: pSig!, count: sigLen)
    // var netStrLength: UInt32 = UInt32(sigLen).bigEndian
    // var sig = Data(bytes: &netStrLength, count: MemoryLayout<UInt32>.size)
    // sig.append(Data(bytes: pSig!, count: sigLen))

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
      throw SSHKeyError(rc, title: "Could not encode key/comment.")
    }

    // String encode
    let rc2 = sshbuf_put_cstring(blob, comment)
    if rc2 != 0 {
      throw SSHKeyError(rc2, title: "Could not encode key/comment.")
    }

    let d = Data(bytes: sshbuf_ptr(blob), count: sshbuf_len(blob))
    sshbuf_free(blob)

    return d
  }

  public func equals(_ blob: Data) -> Bool {
    guard let key = try? SSHKey(fromPublicBlob: blob) else {
      return false
    }

    return sshkey_equal(key.pkey, self.pkey) == 1
  }

  public func privateKeyFileBlob(comment: String? = nil, passphrase: String? = nil) throws -> Data {
    // We could add PEM or PKCS8 for certs
    let format = SSHKEY_PRIVATE_OPENSSH

    guard let blob = sshbuf_new() else {
      throw SSHKeyError(title: "Could not create buffer blob.")
    }
    defer { sshbuf_free(blob) }

    // No special cipher and no rounds
    let rc = sshkey_private_to_fileblob(pkey, blob, passphrase, comment, Int32(format.rawValue), nil, 0)
    if rc != 0 {
      throw SSHKeyError(rc, title: "Error exporting private key to file blob")
    }

    return Data(bytes: sshbuf_ptr(blob), count: sshbuf_len(blob))
  }

  // Encodes as PKCS8. It can do both PEM or PKCS8
  // Accepts passphrase
  // Using OpenSSH keys means we use shielding while the key is not in use but loaded.
  // This is actually a great security feature to brag about.
  //    public func encode(passphrase: String? = nil, format: SSHKeyPrivateFormat) -> Data {
  //        // do_change_passphrase on ssh-keygen is a proper example.
  //        // ssh-keygen main does it that way, so it is definitely way to go and a good example.
  //        // sshkey_save_private -> Saves to a file, we may want to keep a data and encode.
  //        // Is this what keygen uses?
  //        // In old blink we still use libssh functions, which may be causing issues.
  //        // Plus we are serializing the keys instead of using a standard format.
  //        //let rc = sshkey_private_to_fileblob(pkey, )
  //    }
  deinit {
    // TODO Deinit should free the key itself
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
// Encode for File Blob (prepend type and append comment)
// public func SSHPubKeyEncode(key: PublicKey) -> Data {

// }

