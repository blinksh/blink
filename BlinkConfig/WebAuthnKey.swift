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


import AuthenticationServices
import Combine
import Foundation
import SSH
import SwiftCBOR


public protocol InputPrompter {
  func setPromptOnView(_ view: UIView)
}

public class WebAuthnKey: NSObject {
  let rpId: String
  let rawAttestationObject: Data
  
  var termView: UIView? = nil
  //var authAnchor: ASPresentationAnchor? = nil
  var signaturePub: PassthroughSubject<Data, Error>!

  public var comment: String? = nil
  
  public init(rpId: String, rawAttestationObject: Data) throws {
    self.rpId = rpId
    self.rawAttestationObject = rawAttestationObject
  }
  
  func signAuthorizationRequest(_ challenge: Data) -> ASAuthorizationRequest {
    let credentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
    return credentialProvider.createCredentialAssertionRequest(challenge: challenge)
  }
}

public class SKWebAuthnKey: WebAuthnKey {
  override func signAuthorizationRequest(_ challenge: Data) -> ASAuthorizationRequest {
    let credentialProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
    return credentialProvider.createCredentialAssertionRequest(challenge: challenge)
  }
}


extension WebAuthnKey: InputPrompter {
  public func setPromptOnView(_ view: UIView) {
    self.termView = view
  }
}


extension WebAuthnKey: Signer {
  public var publicKey: SSH.PublicKey { self }
  public var sshKeyType: SSH.SSHKeyType { .ecdsaSK }

  // TODO We are going to block here to get the user's input.
  // If this works, the Agent may have to be the one blocking, offering
  // an async interface to the Signers and Constraints.
  public func sign(_ message: Data, algorithm: String?) throws -> Data {
    guard self.termView != nil else {
      throw WebAuthnError.clientError("Prompt not configured for request")
    }

    let authController = ASAuthorizationController(authorizationRequests: [self.signAuthorizationRequest(message)])
    authController.delegate = self
    authController.presentationContextProvider = self
    
    
    if #available(iOS 16.0, *) {
      let semaphore = DispatchSemaphore(value: 0)
      var signature: Data? = nil
      var error: Error? = nil
      self.signaturePub = PassthroughSubject<Data, Error>()
      // TODO Send it on main for now
      let cancel = Just(authController)
        .receive(on: DispatchQueue.main)
        .flatMap { authController in
          authController.performRequests(options: .preferImmediatelyAvailableCredentials)
          return self.signaturePub!
        }
        .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let err):
          error = err
        case .finished:
          break
        }
        semaphore.signal()
      }, receiveValue: { signature = $0 })
      
      semaphore.wait()
      
      guard let signature = signature else {
        throw error!
      }
      
      return signature
    } else {
      // Fallback on earlier versions
      throw WebAuthnError.clientError("Requires iOS >= 16")
    }
  }
}

extension WebAuthnKey: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    
    guard
      let credentialAssertion = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion,
      let rawSignature = credentialAssertion.signature
    else {
      return signaturePub.send(completion: .failure(WebAuthnError.signatureError("Unexpected operation")))
    }

    let rawClientData = credentialAssertion.rawClientDataJSON
    let authData = WebAuthnSSH.decodeAuthenticatorData(
      authData: credentialAssertion.rawAuthenticatorData,
      expectCredential: false
    )
    
    let webAuthnSig = try! WebAuthnSSH.reformatSignature(rawSignature, rawClientData: rawClientData, auth: authData)
    
    // TODO We should validate the CredentialID, to be sure we signed with the proper key,
    // before we fail or ask the user to retry.
    signaturePub.send(webAuthnSig)
    signaturePub.send(completion: .finished)
  }
  
  public func authorizationController(controller: ASAuthorizationController,
                                      didCompleteWithError error: Error) {
    signaturePub.send(completion: .failure(error))
  }
  
  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return self.termView!.window!
  }
}

extension WebAuthnKey : PublicKey {
  public var type: String { "sk-ecdsa-sha2-nistp256@openssh.com" }
  
  public func encode() throws -> Data {
    try WebAuthnSSH.sshKeyFromRawAttestationObject(rawAttestationObject: self.rawAttestationObject, rpId: rpId)
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
        return try? JSONDecoder().decode(ClientData.self, from: data)
    }
    
    static func decodeAuthenticatorData(authData: Data, expectCredential: Bool) -> AuthenticatorData {
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
            // let credentialId = authData[offset..<offset+Int(credentialIdLength)]
            offset += Int(credentialIdLength)
            // CTAP2 canonical CBOR encoded pubkey
            let rawCredentialData = authData[offset...]
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
        let blob = SSHEncode.data(from: "sk-ecdsa-sha2-nistp256@openssh.com") +
        SSHEncode.data(from: "nistp256") +
        // 0x04 - Uncompressed point format
        // -2   - x
        // -3   - y
        SSHEncode.data(from: Data([0x04]) + Data(x) + Data(y)) +
        SSHEncode.data(from: rpId)
        return SSHEncode.data(from: blob)
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
        
//        let seqLength: UInt8 = signature[1]
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
 
  public static func sshKeyFromRawAttestationObject(rawAttestationObject: Data, rpId: String) throws -> Data {
    guard
      let cbor = try? CBOR.decode([UInt8](rawAttestationObject)),
      let authData = cbor["authData"],
      case CBOR.byteString(let bytes) = authData
    else {
      throw WebAuthnError.invalidAttestationObject("Invalid CBOR Data")
    }
      
    let auth = Self.decodeAuthenticatorData(authData: Data(bytes), expectCredential: true)
      
    return try Self.coseToSshPubKey(cborPubKey: auth.rawCredentialData!, rpId: rpId)
  }
}

enum WebAuthnError: Error {
  case keyTypeError(String)
  case invalidAttestationObject(String)
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
