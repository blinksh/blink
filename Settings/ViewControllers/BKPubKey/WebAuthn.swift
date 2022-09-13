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
import AuthenticationServices
import SSH
import SwiftCBOR

// TODO To make this work on Files.app, we may have to move it to BlinkConfig,
// but this will require to have a window handler.
public class WebAuthnKey: Signer {
  public init() {
  }
  
  public var publicKey: SSH.PublicKey { self }
  
  public func sign(_ message: Data, algorithm: String?) throws -> Data {
    Data()
  }
  
  public var comment: String? = nil
  
  public var sshKeyType: SSH.SSHKeyType = .ecdsa
}

extension WebAuthnKey : PublicKey {
  public var type: String { "sk-ecdsa-sha2-nistp256" }
  
  public func encode() throws -> Data {
//    Authenticator Data
//    9d667270fdd60a8fe8902a26ab49ed19c89e02ee8a4574bb62f4366d6fe987f55d0000000000000000000000000000000000000000001411435c321599dc8b56cf5847603ce907017c1cdaa5010203262001215820b8e0c4a6aa98dd012652ef34818bdde366e7e8fe2d1f183584616a2f019eea8a2258203d329134d271248f6242af75479e25a3e562594a744df5b24d68a5df19403463
//    Credential
//    a5010203262001215820b8e0c4a6aa98dd012652ef34818bdde366e7e8fe2d1f183584616a2f019eea8a2258203d329134d271248f6242af75479e25a3e562594a744df5b24d68a5df19403463
    
    let authData = Data(hex: "9d667270fdd60a8fe8902a26ab49ed19c89e02ee8a4574bb62f4366d6fe987f55d0000000000000000000000000000000000000000001411435c321599dc8b56cf5847603ce907017c1cdaa5010203262001215820b8e0c4a6aa98dd012652ef34818bdde366e7e8fe2d1f183584616a2f019eea8a2258203d329134d271248f6242af75479e25a3e562594a744df5b24d68a5df19403463")!
    
    let auth = WebAuthnSSH.decodeAuthenticatorData(authData: authData, expectCredential: true)
    
    return try WebAuthnSSH.coseToSshPubKey(cborPubKey: auth.rawCredentialData!, rpId: "blink.sh")
  }
}

struct AuthenticatorData {
    let rpIdHash: Data
    let flags: UInt8
    let count: UInt32
    let aaguid: Data?
    let credentialIdLength: UInt16?
    let rawCredentialData: Data?
    let extensions: Data?
}

struct ClientData: Decodable {
    let challenge: String
    let origin: String
    let type: String
    // let crossOrigin: bool
}

public enum WebAuthnSSH {
    static func decodeClientData(_ data: Data) -> ClientData? {
        print("Client Data")
        print(data.hexEncodedString())
        // Decode JSON from Data
        return try? JSONDecoder().decode(ClientData.self, from: data)
    }
    
//    static func decodeAttestationData(attData: Data) {
//        let f = try! CBOR.decode([UInt8](attData))!
//        let authData = f["authData"]!
//        print(authData)
//        if case CBOR.byteString(let bytes) = authData {
//            // Process bytes
//            let res = decodeAuthenticatorData(authData: Data(bytes), expectCredential: true)
//        }
//    }
    
    static func decodeAuthenticatorData(authData: Data, expectCredential: Bool) -> AuthenticatorData {
        print("Authenticator Data")
        print(authData.hexEncodedString())
        
        let rpIdHash = authData[0..<32]
        let flags: UInt8 = authData[32]
        var count: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &count, { authData[33..<37].copyBytes(to: $0)})
        count = UInt32(bigEndian: count)
        
        var offset = 37
        if expectCredential {
            // https://w3c.github.io/webauthn/#sctn-attested-credential-data
            let aaguid = authData[offset..<offset+16]
            offset += 16
            var credentialIdLength: UInt16 = 0
            _ = withUnsafeMutableBytes(of: &credentialIdLength, { authData[offset..<offset+2].copyBytes(to: $0)})
            // https://forums.swift.org/t/how-to-handle-endianess/53558/4
            credentialIdLength = UInt16(bigEndian: credentialIdLength)
            offset += 2
            let credentialId = authData[offset..<offset+Int(credentialIdLength)]
            offset += Int(credentialIdLength)
            // CTAP2 canonical CBOR encoded pubkey
            let rawCredentialData = authData[offset...]
            print("Credential")
            print(rawCredentialData.hexEncodedString())
            return AuthenticatorData(rpIdHash: rpIdHash, flags: flags, count: count, aaguid: aaguid, credentialIdLength: credentialIdLength, rawCredentialData: rawCredentialData, extensions: nil)
        } else {
            // Extensions, can be ignored for now.
            let extensions = authData[offset...]
            return AuthenticatorData(rpIdHash: rpIdHash, flags: flags, count: count, aaguid: nil, credentialIdLength: nil, rawCredentialData: nil, extensions: extensions)
        }
    }
    
    static func coseToSshPubKey(cborPubKey: Data, rpId: String) throws -> Data {
        let pk = try! CBOR.decode([UInt8](cborPubKey))!
        // EC, P256 and ES256 signatures
        if pk[1] != 2 {
            throw WebAuthnError.keyTypeError("Pubkey is not EC")
        }
        if pk[-1] != 1 {
            throw WebAuthnError.keyTypeError("Pubkey not in P256 curve")
        }
        if pk[3] != -7 {
            throw WebAuthnError.keyTypeError("Pubkey not ES256")
        }
        
        guard let px = pk[-2], let py = pk[-3],
              case CBOR.byteString(let x) = px,
              case CBOR.byteString(let y) = py else {
            throw WebAuthnError.keyTypeError("Could not find point x, y")
        }
        return SSHEncode.data(from: "sk-ecdsa-sha2-nistp256@openssh.com") +
        SSHEncode.data(from: "nistp256") +
        // 0x04 - Uncompressed point format
        // -2   - x
        // -3   - y
        SSHEncode.data(from: Data([0x04]) + Data(x) + Data(y)) +
        SSHEncode.data(from: rpId)
        
    }
    
    static func reformatSignature(_ signature: Data,
                                  rawClientData: Data,
                                  auth: AuthenticatorData) throws -> Data {
        if signature.count < 2 {
            throw WebAuthnError.signatureError("Signature is too short")
        }
        
        // Get components
        let seq: UInt8 = signature[0]
        if seq != 0x30 {
            throw WebAuthnError.signatureError("Not an ASN.1 sequence")
        }
        
        let seqLength: UInt8 = signature[1]
        let r: UInt8 = signature[2]
        if r != 0x02 {
            throw WebAuthnError.signatureError("Signature r not an ASN.1 integer")
        }
        let rLength: UInt8 = signature[3]
        
        var sigOffset = 4
        let rSig: Data = signature[sigOffset..<sigOffset+Int(rLength)]
        
        sigOffset += Int(rLength)
        let s: UInt8 = signature[sigOffset]
        if s != 0x02 {
            throw WebAuthnError.signatureError("Signature s not an ASN.1 integer")
        }
        let sLength: UInt8 = signature[sigOffset+1]
        sigOffset += 2
        let sSig = signature[sigOffset..<sigOffset+Int(sLength)]
        
        sigOffset += Int(sLength)
        if sigOffset != signature.count {
            throw WebAuthnError.signatureError("Offset did not reach end of signature.")
        }
        
        guard let client = Self.decodeClientData(rawClientData) else {
            throw WebAuthnError.clientError("Could not parse clientData")
        }
        
        // Reformat
        let sig = SSHEncode.data(from: rSig) + SSHEncode.data(from: sSig)
        let ext = auth.extensions == nil ? SSHEncode.data(from: UInt32(0)) : SSHEncode.data(from: auth.extensions!)
        
        return SSHEncode.data(from: "webauthn-sk-ecdsa-sha2-nistp256@openssh.com") +
        SSHEncode.data(from: sig) +
        // TODO Unsure about this
        Data([auth.flags]) +
        SSHEncode.data(from: auth.count) +
        SSHEncode.data(from: client.origin) +
        // We can force if it was able to decode the JSON.
        SSHEncode.data(from: String(data: rawClientData, encoding: .utf8)!) +
        ext
    }
    
}

enum WebAuthnError: Error {
    case keyTypeError(String)
    case signatureError(String)
    case clientError(String)
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }
}

extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }
        
        let chars = hex.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }
        
        guard hex.count / bytes.count == 2 else { return nil }
        self.init(bytes)
    }
}
