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

struct KeyDetailsView: View {
  @State var card: BKPubKey
  let reloadCards: () -> ()
  
  @EnvironmentObject private var _nav: Nav
  @State private var _keyName: String = ""
  @State private var _certificate: String? = nil
  @State private var _originalCertificate: String? = nil
  @State private var _pubkeyLines = 1
  @State private var _certificateLines = 1
  
  @State private var _actionSheetIsPresented = false
  @State private var _filePickerIsPresented = false
  
  @State private var _errorAlertIsPresented = false
  @State private var _errorMessage = ""
  
  private func _copyPublicKey() {
    UIPasteboard.general.string = card.publicKey
  }
  
  private func _copyCertificate() {
    UIPasteboard.general.string = _certificate ?? ""
  }
  
  var _saveIsDisabled: Bool {
    (card.id == _keyName && _certificate == _originalCertificate) || _keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  private func _showError(message: String) {
    _errorMessage = message
    _errorAlertIsPresented = true
  }
  
  private func _importCertificateFromClipboard() {
    do {
      guard
        let str = UIPasteboard.general.string,
        !str.isEmpty
      else {
        return _showError(message: "Pasteboard is empty")
      }
      
      guard let blob = str.data(using: .utf8) else {
        return _showError(message: "Can't convert to string with UTF8 encoding")
      }
      try _importCertificateFromBlob(blob)
    } catch {
      _showError(message: error.localizedDescription)
    }
  }
  
  private func _importCertificateFromFile(result: Result<URL, Error>) {
    do {
      let url = try result.get()
      guard
        url.startAccessingSecurityScopedResource()
      else {
        return _showError(message: "Can't read get access to read file.")
      }
      defer {
        url.stopAccessingSecurityScopedResource()
      }
      
      let blob = try Data(contentsOf: url, options: .alwaysMapped)
      
      try _importCertificateFromBlob(blob)
    } catch {
      _showError(message: error.localizedDescription)
    }
  }
  
  private func _importCertificateFromBlob(_ certBlob: Data) throws {
    guard
      let privateKey = card.loadPrivateKey(),
      let privateKeyBlob = privateKey.data(using: .utf8)
    else {
      return _showError(message: "Can't load private key")
    }
    
    _ = try SSHKey(fromFileBlob: privateKeyBlob, passphrase: "", withPublicFileCertBlob: SSHKey.sanitize(key: certBlob))
    
    _certificate = String(data: certBlob, encoding: .utf8)
  }
  
  private func _sharePublicKey(frame: CGRect) {
    let activityController = UIActivityViewController(activityItems: [card], applicationActivities: nil);
  
    activityController.excludedActivityTypes = [
      .postToTwitter, .postToFacebook,
      .assignToContact, .saveToCameraRoll,
      .addToReadingList, .postToFlickr,
      .postToVimeo, .postToWeibo
    ]

    activityController.popoverPresentationController?.sourceView = _nav.navController.view
    activityController.popoverPresentationController?.sourceRect = frame
    _nav.navController.present(activityController, animated: true, completion: nil)
  }
  
  private func _copyPrivateKey() {
    LocalAuth.shared.authenticate(callback: { success in
      guard
        success,
        let privateKey = card.loadPrivateKey()
      else {
        return
      }
      UIPasteboard.general.string = privateKey
      
    }, reason: "to copy private key to clipboard.")
  }
  
  private func _removeCertificate() {
    _certificate = nil
  }
  
  private func _deleteCard() {
    LocalAuth.shared.authenticate(callback: { success in
      if success {
        BKPubKey.removeCard(card: card)
        reloadCards()
        _nav.navController.popViewController(animated: true)
      }
    }, reason: "to delete key.")
  }
  
  
  private func _saveCard() {
    let keyID = _keyName.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      if keyID.isEmpty {
        throw KeyUIError.emptyName
      }
      
      if let oldKey = BKPubKey.withID(keyID) {
        if oldKey !== _card.wrappedValue {
          throw KeyUIError.duplicateName(name: keyID)
        }
      }
      
      _card.wrappedValue.id = keyID
      _card.wrappedValue.storeCertificate(inKeychain: _certificate)
      
      BKPubKey.saveIDS()
      _nav.navController.popViewController(animated: true)
      self.reloadCards()
    } catch {
      _showError(message: error.localizedDescription)
    }
  }
  
  var body: some View {
    List {
      Section(
        header: Text("NAME"),
        footer: Text("Default key must be named `id_\(card.keyType?.lowercased() ?? "")`")
      ) {
        HStack {
          FixedTextField(
            "Enter a name for the key",
            text: $_keyName,
            id: "keyName",
            nextId: "keyComment",
            autocorrectionType: .no,
            autocapitalizationType: .none
          )
        }
      }
      
      Section(header: Text("Public Key")) {
        HStack {
          Text(card.publicKey).lineLimit(_pubkeyLines)
        }.onTapGesture {
          _pubkeyLines = _pubkeyLines == 1 ? 100 : 1
        }
        Button(action: _copyPublicKey, label: {
          Label("Copy", systemImage: "doc.on.doc")
        })
        GeometryReader(content: { geometry in
          let frame = geometry.frame(in: .global)
          Button(action: { _sharePublicKey(frame: frame) }, label: {
            Label("Share", systemImage: "square.and.arrow.up")
          }).frame(width: frame.width, height: frame.height, alignment: .leading)
        })
      }
     
      if card.storageType == BKPubKeyStorageTypeKeyChain {
        if let certificate = _certificate {
          Section(header: Text("Certificate")) {
            HStack {
              Text(certificate).lineLimit(_certificateLines)
            }.onTapGesture {
              _certificateLines = _certificateLines == 1 ? 100 : 1
            }
            Button(action: _copyCertificate, label: {
              Label("Copy", systemImage: "doc.on.doc")
            })
            Button(action: _removeCertificate, label: {
              Label("Remove", systemImage: "minus.circle")
            }).accentColor(.red)
          }
        } else {
          Section() {
            Button(
              action: { _actionSheetIsPresented = true },
              label: {
                Label("Add Certificate", systemImage: "plus.circle")
              }
            )
            .actionSheet(isPresented: $_actionSheetIsPresented) {
                ActionSheet(
                  title: Text("Add Certificate"),
                  buttons: [
                    .default(Text("Import from clipboard")) { _importCertificateFromClipboard() },
                    .default(Text("Import from a file")) { _filePickerIsPresented = true },
                    .cancel()
                  ]
                )
            }
          }
        }
        
        Section() {
          Button(action: _copyPrivateKey, label: {
            Label("Copy private key", systemImage: "doc.on.doc")
          })
        }
      }
      
      Section() {
        Button(action: _deleteCard, label: {
          Label("Delete", systemImage: "trash")
        }).accentColor(.red)
      }
    }
    .listStyle(GroupedListStyle())
    .navigationTitle("Key Info")
    .navigationBarItems(
      trailing: Button("Save", action: _saveCard)
      .disabled(_saveIsDisabled)
    )
    .fileImporter(
      isPresented: $_filePickerIsPresented,
      allowedContentTypes: [.text, .data, .item],
      onCompletion: _importCertificateFromFile
    )
    .onAppear(perform: {
      _keyName = card.id
      _certificate = card.loadCertificate()
      _originalCertificate = _certificate
    })
    
    .alert(isPresented: $_errorAlertIsPresented) {
      Alert(
        title: Text("Error"),
        message: Text(_errorMessage),
        dismissButton: .default(Text("Ok"))
      )
    }
  }
}
