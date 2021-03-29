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

fileprivate struct KeyCard {
  let key: BKPubKey
  let name: String
  let keyType: String?
  let certType: String?
  
  init(key: BKPubKey) {
    self.key = key
    self.name = key.id
    self.keyType = key.keyType
    self.certType = key.certType
  }
}

struct KeyRow: View {
  fileprivate var card: KeyCard
  var reloadCards: () -> ()
  
  var body: some View {
    Row(
      content: {
        HStack {
          VStack(alignment: .leading) {
            Text(card.name)
            Text([card.keyType, card.certType].compactMap({$0}).joined(separator: " + ")).font(.footnote)
              .foregroundColor(.secondary)
          }
          Spacer()
          Text(card.key.storageType == BKPubKeyStorageTypeKeyChain ? "Keychain" : "SE")
            .font(.system(.subheadline))
            
        }
      },
      details: {
        KeyDetailsView(card: card.key, reloadCards: reloadCards)
      }
    )
  }
}


struct KeysListView: View {
  @EnvironmentObject var nav: Nav
  @StateObject private var state = KeysObservable()
  
  var body: some View {
    List {
      ForEach(state.list, id: \.name) {
        KeyRow(card: $0, reloadCards: state.reloadCards)
      }.onDelete(perform: { indexSet in
        state.deleteKeys(indexSet: indexSet)
      })
    }
    .navigationBarItems(
      trailing: Button(
        action: {
          state.actionSheetIsPresented = true
        },
        label: {
          Image(systemName: "plus")
        }
      )
      .actionSheet(isPresented: $state.actionSheetIsPresented) {
          ActionSheet(
            title: Text("Add key"),
            buttons: [
              .default(Text("Generate New")) { state.modal = .newKey },
              .default(Text("Generate New in SE")) { state.modal = .newSEKey },
              .default(Text("Import from clipboard")) { state.importFromClipboard() },
              .default(Text("Import from a file")) { state.filePickerIsPresented = true },
              .cancel()
            ]
          )
      }
    )
    .navigationBarTitle("Keys")
    
    .fileImporter(
      isPresented: $state.filePickerIsPresented,
      allowedContentTypes: [.text, .data, .item],
      onCompletion: state.importFromFile
    )
    .sheet(item: $state.modal, onDismiss: {
      
    }) { modal in
      switch (modal) {
      case .passphrasePrompt(let keyBlob, let proposedName):
        NavigationView {
          PassphraseView(
            keyBlob: keyBlob,
            keyProposedName: proposedName,
            onCancel: {
              self.state.modal = nil
            },
            onSuccess: {
              self.state.modal = nil
              self.state.reloadCards()
            }
          )
        }
      case .saveImportedKey(let observable):
        NavigationView {
          ImportKeyView(
            state: observable,
            onCancel: { state.modal = nil },
            onSuccess: {
              state.modal = nil
              state.reloadCards()
            }
          )
        }
      case .newKey:
        NavigationView {
          NewKeyView(
            onCancel: {
              state.modal = nil
            },
            onSuccess: {
              state.modal = nil
              state.reloadCards()
            }
          )
        }
      case .newSEKey:
        NavigationView {
          NewSEKeyView(
            onCancel: {
              state.modal = nil
            },
            onSuccess: {
              state.modal = nil
              state.reloadCards()
            }
          )
        }
      }
    }
    .alert(isPresented: $state.errorAlertIsPresented) {
      Alert(
        title: Text("Error"),
        message: Text(state.errorMessage),
        dismissButton: .default(Text("Ok"))
      )
    }
  }
}

fileprivate class KeysObservable: ObservableObject {
  
  @Published var list: [KeyCard] = BKPubKey.all().map( {KeyCard(key: $0 )} )
  @Published var actionSheetIsPresented: Bool = false
  @Published var errorAlertIsPresented: Bool = false
  @Published var filePickerIsPresented: Bool = false
  @Published var modal: KeyModals? = nil
  var addKeyObservable: ImportKeyObservable? = nil
  var errorMessage = ""
  var proposedKeyName = ""
  
  init() {
    
  }
  
  func reloadCards() {
    self.list = BKPubKey.all().map( {KeyCard(key: $0 )} )
  }
  
  func removeKey(card: BKPubKey) {
    BKPubKey.removeCard(card: card)
    list.removeAll { k in
      k.key.tag == card.tag
    }
  }
  
  func deleteKeys(indexSet: IndexSet) {
    guard let index = indexSet.first else {
      return
    }
    
    let card = list[index]
    self.list.remove(atOffsets: indexSet)
    
    LocalAuth.shared.authenticate(callback: { success in
      if success {
        BKPubKey.removeCard(card: card.key)
      } else {
        self.reloadCards()
      }
    }, reason: "to delete key.")
  }
  
  func importFromFile(result: Result<URL, Error>) {
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
      _importKeyFromBlob(blob: blob, proposedKeyName: url.lastPathComponent)
    } catch {
      _showError(message: error.localizedDescription)
    }
  }
  
  func importFromClipboard() {
    guard
      let string = UIPasteboard.general.string,
      !string.isEmpty
    else {
      return _showError(message: "Clipboard is empty");
    }
    
    guard
      let blob = string.data(using: .utf8)
    else {
      return _showError(message: "Can't convert to data")
    }
    
    _importKeyFromBlob(blob: blob, proposedKeyName: "")
  }
  
  private func _importKeyFromBlob(blob: Data, proposedKeyName: String) {
    do {
      let key = try SSHKey(fromFileBlob: blob, passphrase: "")
      modal = .saveImportedKey(ImportKeyObservable(key: key, keyName: proposedKeyName, keyComment: key.comment ?? ""))
    } catch SSHKeyError.wrongPassphrase {
      modal = .passphrasePrompt(keyBlob: blob, proposedKeyName: proposedKeyName)
    } catch {
      return _showError(message: error.localizedDescription)
    }
  }
  
  private func _showError(message: String) {
    errorMessage = message
    errorAlertIsPresented = true
  }
}


enum KeyModals: Identifiable {
  case passphrasePrompt(keyBlob: Data, proposedKeyName: String)
  case saveImportedKey(ImportKeyObservable)
  case newKey
  case newSEKey
  
  var id: Int {
    switch self {
    case .passphrasePrompt: return 0
    case .saveImportedKey: return 1
    case .newKey: return 2
    case .newSEKey: return 3
    }
  }
}

extension View {
  func navigatePush(whenTrue toggle: Binding<Bool>) -> some View {
    NavigationLink(
      destination: self,
      isActive: toggle
    ) { EmptyView() }
  }
  
  func navigatePush<H>(whenPresent toggle: Binding<H?>) -> some View {
    navigatePush(
      whenTrue: Binding(
        get: { toggle.wrappedValue != nil },
        set: {
          if !$0 {
            toggle.wrappedValue = nil
          }
        }
      )
    )
  }
}


enum KeyUIError: Error, LocalizedError {
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
