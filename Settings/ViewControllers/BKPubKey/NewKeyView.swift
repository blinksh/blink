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


import SwiftUI
import SSH

@objc public protocol NewKeyViewDelegate: AnyObject {
  @objc func newKeyGenerated()
}

struct NewKeyView: View {
  @EnvironmentObject var nav: Nav
  @StateObject fileprivate var state = NewKeyObservable()
  var delegate: NewKeyViewDelegate
  
  var body: some View {
    List {
      Section(header: Text("NAME"),
              footer: Text("Default key must be named `id_\(state.keyType.name.lowercased())`")) {
        HStack {
          TextField("Enter a name for the key", text: $state.keyName)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
      }
      
      Section(header: Text("KEY TYPE"),
              footer: Text(state.keyType.keyHint)) {
        HStack {
          Picker("", selection: $state.keyType) {
            Text(SSHKeyType.KEY_DSA.name).tag(SSHKeyType.KEY_DSA)
            Text(SSHKeyType.KEY_RSA.name).tag(SSHKeyType.KEY_RSA)
            Text(SSHKeyType.KEY_ECDSA.name).tag(SSHKeyType.KEY_ECDSA)
            Text(SSHKeyType.KEY_ED25519.name).tag(SSHKeyType.KEY_ED25519)
          }
          .pickerStyle(SegmentedPickerStyle())
        }
        if state.keyType.possibleBitsValues.count > 1 {
          HStack {
            Text("Bits").layoutPriority(1)
            Spacer().layoutPriority(1)
            VStack {
              Picker("", selection: $state.keyBits) {
                ForEach(state.keyType.possibleBitsValues, id: \.self) { bits in
                  Text("\(bits)").tag(bits)
                }
              }
              .pickerStyle(SegmentedPickerStyle())
            }.layoutPriority(1)
          }
        }
      }
      
      Section(header: Text("COMMENT (OPTIONAL)")) {
        HStack {
          TextField("Comment for your key", text: $state.keyComment).autocapitalization(.none).disableAutocorrection(true)
        }
      }
      
      Section(header: Text("INFORMATION"),
              footer: Text("Blink creates PKCS#8 public and private keys, with AES 256 bit encryption. Use \"ssh-copy-id [name]\" to copy the public key to the server.")
      ) {
        
      }
    }
    .listStyle(GroupedListStyle())
    .navigationBarItems(
      trailing: Button("Create") {
        if state.createKey() {
          delegate.newKeyGenerated()
        }
      }
      .disabled(!state.isValid)
    )
    .navigationBarTitle("New \(state.keyType.name) Key")
    .alert(isPresented: $state.errorAlertVisible) {
      Alert(title: Text("Error"), message: Text(state.errorMessage), dismissButton: .default(Text("Ok")))
    }
  }
}

fileprivate class NewKeyObservable: ObservableObject {
  enum KeyError: Error, LocalizedError {
    case emptyName
    case duplicateName(name: String)
    case authKeyGenerationFailed
    case saveCardFailed
    case generationFailed
    
    var errorDescription: String? {
      switch self {
      case .emptyName: return "Key name can't be empty."
      case .duplicateName(let name): return "Key with name `\(name)` already exists."
      case .authKeyGenerationFailed: return "Could not generate public key."
      case .saveCardFailed: return "Can't save key."
      case .generationFailed: return "Generation failed"
      }
    }
  }
  
  @Published var keyType: SSHKeyType = .KEY_RSA {
    didSet {
      keyBits = keyType.possibleBitsValues.last ?? 0
    }
  }
  @Published var keyName: String = ""
  @Published var keyBits: UInt32 = 4096
  @Published var keyComment: String = "\(BKDefaults.defaultUserName() ?? "")@\(UIDevice.getInfoType(fromDeviceName: BKDeviceInfoTypeDeviceName) ?? "")"
  
  @Published var errorAlertVisible: Bool = false
  
  var errorMessage = ""
  
  var isValid: Bool {
    !keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  func createKey() -> Bool {
    errorMessage = ""
    let keyID = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
    let comment = keyComment.trimmingCharacters(in: .whitespacesAndNewlines)
    
    do {
      if keyID.isEmpty {
        throw KeyError.emptyName
      }
      
      if BKPubKey.withID(keyID) != nil {
        throw KeyError.duplicateName(name: keyID)
      }
      
      let key        = try SSHKey(type: keyType, bits: keyBits)
      let privateKey = try key.privateKeyFileBlob(comment: comment, passphrase: nil).base64EncodedString()
      let authKey    = try key.authorizedKey(withComment: comment)
      
      guard
        let _ = BKPubKey.saveCard(keyID, privateKey: privateKey, publicKey: authKey)
      else {
        throw KeyError.saveCardFailed
      }
    } catch {
      errorMessage = error.localizedDescription
      errorAlertVisible = true
      return false
    }

    return true
  }
}

fileprivate extension SSHKeyType {
  var possibleBitsValues: [UInt32] {
    switch self {
    case .KEY_DSA:     return [1024]
    case .KEY_RSA:     return [2048, 4096]
    case .KEY_ECDSA:   return [256, 384, 521]
    case .KEY_ED25519: return []
    default:           return []
    }
  }
  
  var name: String {
    switch self {
    case .KEY_DSA:     return "DSA"
    case .KEY_RSA:     return "RSA"
    case .KEY_ECDSA:   return "ECDSA"
    case .KEY_ED25519: return "Ed25519"
    default:           return ""
    }
  }
  
  var keyHint: String {
    switch self {
    case .KEY_DSA: return "DSA keys must be exactly 1024 bits as specified by FIPS 186-2."
    case .KEY_RSA: return "Generally, 2048 bits is considered sufficient."
    case .KEY_ECDSA: return "For ECDSA keys size determines key length by selecting from one of three elliptic curve sizes: 256, 384 or 521 bits."
    case .KEY_ED25519: return "Ed25519 keys have a fixed length."
    default: return ""
    }
  }
}
