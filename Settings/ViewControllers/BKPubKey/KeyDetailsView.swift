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

struct KeyDetailsView: View {
  @EnvironmentObject var nav: Nav
  
  @State var card: BKPubKey
  
  @State var shareCard: BKPubKey? = nil
  
  @State var keyName: String = ""
  @State var pubkeyLines = 1
  
  @State var errorAlertIsPresented = false
  @State var errorMessage = ""
  
  var reloadCards: () -> ()
  
  private func _copyPublicKey() {
    UIPasteboard.general.string = card.publicKey
  }
  
  private func _sharePublicKey(frame: CGRect) {
    let activityController = UIActivityViewController(activityItems: [card], applicationActivities: nil);
  
    activityController.excludedActivityTypes = [
      .postToTwitter, .postToFacebook,
      .assignToContact, .saveToCameraRoll,
      .addToReadingList, .postToFlickr,
      .postToVimeo, .postToWeibo
    ]

    activityController.popoverPresentationController?.sourceView = nav.navController.view
    activityController.popoverPresentationController?.sourceRect = frame
    nav.navController.present(activityController, animated: true, completion: nil)
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
  
  private func _deleteCard() {
    LocalAuth.shared.authenticate(callback: { success in
      if success {
        BKPubKey.removeCard(card: card)
        reloadCards()
        nav.navController.popViewController(animated: true)
      }
    }, reason: "to delete key.")
  }
  
  
  private func _saveCard() {
    let keyID = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      if keyID.isEmpty {
        throw KeyUIError.emptyName
      }
      
      if BKPubKey.withID(keyID) != nil {
        throw KeyUIError.duplicateName(name: keyID)
      }
      
      _card.wrappedValue.id = keyID
      
      BKPubKey.saveIDS()
      nav.navController.popViewController(animated: true)
      self.reloadCards()
    } catch {
      errorMessage = error.localizedDescription
      errorAlertIsPresented = true
    }
  }
  
  var body: some View {
    List {
      Section(header: Text("NAME"),
              footer: Text("Default key must be named `id_\(card.keyType?.lowercased() ?? "")`")) {
        HStack {
          FixedTextField(
            "Enter a name for the key",
            text: $keyName,
            id: "keyName",
            nextId: "keyComment",
            autocorrectionType: .no,
            autocapitalizationType: .none
          )
        }
      }
      
      Section(header: Text("Public Key")) {
        HStack {
          Text(card.publicKey).lineLimit(pubkeyLines)
        }.onTapGesture {
          self.pubkeyLines = self.pubkeyLines == 1 ? 100 : 1
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
        Section() {
          Button(action: _copyPrivateKey, label: {
            Label("Copy private key", systemImage: "doc.on.doc")
          })
        }
      }
      
      Section() {
        Button(action: _copyPrivateKey, label: {
          Label("Add Certificate", systemImage: "plus")
        })
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
      .disabled(card.id == keyName || keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    )
    .onAppear(perform: {
      keyName = card.id
    })
    .alert(isPresented: $errorAlertIsPresented) {
      Alert(
        title: Text("Error"),
        message: Text(errorMessage),
        dismissButton: .default(Text("Ok"))
      )
    }
  }
}
