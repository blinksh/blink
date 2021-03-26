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

struct PassphraseView: View {
  @State var passphrase: String = ""
  @State var errorMessage: String = ""
  @State var errorAlertIsPresented: Bool = false
  
  var keyBlob: Data
  var keyProposedName: String
  var onCancel: () -> ()
  var onSuccess: () -> ()
  
  @State var importKeyObservable: ImportKeyObservable? = nil
  
  private func _onUnlock() {
    do {
      let key = try SSHKey(fromFileBlob: keyBlob, passphrase: passphrase)
      importKeyObservable = ImportKeyObservable(key: key, keyName: keyProposedName, keyComment: key.comment ?? "")
    } catch {
      return _showError(message: error.localizedDescription)
    }
  }
    
  private func _showError(message: String) {
    errorMessage = message
    errorAlertIsPresented = true
  }
  
  var body: some View {
    VStack {
      Image(systemName: "lock.doc").resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 80).padding()
      Text("This key is protected with passphrase").padding()
      FixedTextField(
        "Passphrase",
        text: $passphrase,
        id: "passphrase",
        secureTextEntry: true,
        autocorrectionType: .no,
        autocapitalizationType: .none
      )
      .frame(maxHeight: 50)
      .padding()
      Button("Unlock", action: _onUnlock).disabled(passphrase.isEmpty)
      
      Spacer()
      
      Group {
        if let importObservable = self.importKeyObservable {
          ImportKeyView(state: importObservable, onCancel: onCancel, onSuccess: onSuccess)
        }
      }
      .navigationBarBackButtonHidden(true)
      .navigatePush(whenPresent: $importKeyObservable)
    }
    .navigationBarItems(
      leading: Button("Cancel", action: onCancel)
    )
    .onAppear() {
      FixedTextField.becomeFirstReponder(id: "passphrase")
    }
    .alert(isPresented: $errorAlertIsPresented) {
      Alert(
        title: Text("Error"),
        message: Text(errorMessage),
        dismissButton: .default(Text("Ok"))
      )
    }
  }
}
