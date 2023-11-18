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

//MARK: - Key Card Model
fileprivate struct KeyCard {
  let key: BKPubKey
  let name: String
  let keyType: String?
  let certType: String?
  let isAccessible: Bool

  init(key: BKPubKey) {
    self.key = key
    self.name = key.id
    self.keyType = key.keyType
    self.certType = key.certType
    self.isAccessible = BKPubKey.all().signerWithID(name) != nil ? true : false
  }
}


//MARK: - Key Row View
struct KeyRow: View {
  fileprivate let card: KeyCard
  let reloadCards: () -> ()

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
          if card.isAccessible {
            Text(card.key.storageType.shortName())
              .font(.system(.subheadline))
          } else {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.yellow)
          }
        }
      },
      details: {
        KeyDetailsView(card: card.key, reloadCards: reloadCards)
      }
    )
  }
}


//MARK: - Main Key Sort View
struct KeySortView: View {
  @Binding fileprivate var sortType: KeysObservable.KeySortType

  var body: some View {
    Menu {
      Section(header: Text("Order")) {
        SortButton(label: "Name",    sortType: $sortType, asc: .nameAsc, desc: .nameDesc)
        SortButton(label: "Type",    sortType: $sortType, asc: .typeAsc, desc: .typeDesc)
        SortButton(label: "Storage", sortType: $sortType, asc: .storageAsc, desc: .storageDesc)
      }
    } label: { Image(systemName: "list.bullet").frame(width: 38, height: 38, alignment: .center) }

  }
}


//MARK: - Main New Key View
struct NewKeyMenuContentView: View {
  
  @Binding var isMenuPresented: Bool
  
  fileprivate var state: KeysObservable
  
  var body: some View {
    NavigationView {
      Form {
        plainTextKeySection
        secureEnclaveKeySection
        passkeySection
      }
      .onAppear {
        UITableView.appearance().sectionFooterHeight = 0
      }
      .navigationTitle("New Key")
      .navigationBarTitleDisplayMode(.large)
      .navigationBarItems(
        trailing:
          HStack {
            Button {
              dismissView()
            } label: {
              Image(systemName: "multiply.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.gray)
            }
          }
      )
    }
  }
}


//MARK: - New Key View properties
private extension NewKeyMenuContentView {
  var plainTextKeySection: some View {
    Section {
      HStack {
        VStack {
          baseCellIcon(systemName: "key.horizontal.fill")
          Spacer()
        }
        .padding([.top], 10)
        .padding([.trailing], 8)
        
        VStack(alignment: .leading) {
          baseCellTitle("Plain-text Key")
          baseCellSubtitle("Create RSA, EDSA and ED25519 keys, securely stored in the keychain.")
          
          actionsDivider()
          actionButtonTitle(title: "Generate New", tintColor: .systemTeal)
            .onTapGesture {
              dismissView()
              self.state.modal = .newKey
            }
          actionsDivider()
          actionButtonTitle(title: "Import from File", tintColor: .label)
            .onTapGesture {
              dismissView()
              self.state.filePickerIsPresented = true
            }
          actionsDivider()
          actionButtonTitle(title: "Import from Clipboard", tintColor: .label)
            .onTapGesture {
              dismissView()
              self.state.importFromClipboard()
            }
        }
        .padding([.top], 4)
      }
    }
  }
  var secureEnclaveKeySection: some View {
    Section {
      HStack {
        VStack {
          baseCellIcon(systemName: "cpu.fill")
          Spacer()
        }
        .padding([.top], 10)
        .padding([.trailing], 8)
        
        VStack(alignment: .leading) {
          baseCellTitle("Secure Enclave Key")
          baseCellSubtitle("Isolated in your device, enhances security by managing keys without exposing plain-text.")
          
          actionsDivider()
          actionButtonTitle(title: "Generate New", tintColor: .systemTeal)
            .onTapGesture {
              dismissView()
              self.state.modal = .newSecurityKey
            }
        }
        .padding([.top], 4)
      }
    }
  }
  var passkeySection: some View {
    Section {
      HStack {
        VStack {
          baseCellIcon(systemName: "person.badge.key.fill")
          Spacer()
        }
        .padding([.top], 10)
        .padding([.trailing], 8)
        
        VStack(alignment: .leading) {
          baseCellTitle("Passkey (experimental)")
          baseCellSubtitle("WebAuth keys for SSH are stored in your device or hardware key. Limitations apply.")
          
          actionsDivider()
          actionButtonTitle(title: "Generate on device", tintColor: .systemTeal)
            .onTapGesture {
              dismissView()
              self.state.modal = .newPasskey
            }
          actionsDivider()
          actionButtonTitle(title: "Generate on Hardware key", tintColor: .label)
            .onTapGesture {
              dismissView()
              self.state.modal = .newPasskey
            }
        }
        .padding([.top], 4)
      }
    }
  }
  
  
  //MARK: Fast methods
  func dismissView() {
    self.isMenuPresented = false
  }
  
  
  //MARK: Fast New Key properties
  func baseCellTitle(_ content: String) -> some View {
    Text(content)
      .font(.system(size: 16, weight: .semibold))
      .frame(height: 14)
  }
  
  func baseCellSubtitle(_ content: String) -> some View {
    Text("\(content)\n[Read more.](https://github.com/blinksh/blink)")
      .font(.system(size: 14, weight: .regular))
      .foregroundStyle(Color.secondary)
  }
  
  func baseCellIcon(systemName: String) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .stroke(.secondary.opacity(0.3), lineWidth: 0.8)
        .frame(width: 42, height: 42)
      
      Image(systemName: systemName)
        .foregroundStyle(Color.teal)
    }
    .frame(maxWidth: 42, maxHeight: 42)
  }
  
  func actionButtonTitle(title: String, tintColor: UIColor) -> some View {
    Text(title)
      .foregroundStyle(Color(tintColor))
      .font(.system(size: 16))
  }
  
  func actionsDivider() -> some View {
    Divider()
      .padding(.bottom, 1)
      .padding(.trailing, -20)
  }
}


//MARK: - Main Keys List View
struct KeyListView: View {
  @StateObject private var _state = KeysObservable()
  
  @Environment(\.presentationMode) var presentationMode
  @State private var isMenuPresented = false

  var body: some View {
    Group {
      if _state.list.isEmpty {
        EmptyStateHandlerView(
          action: toggleNewKeyView, 
          title: "Add Key",
          systemIconName: "key"
        )
      } else {
        List {
          Section {
            ForEach(_state.list, id: \.name) {
              KeyRow(card: $0, reloadCards: _state.reloadCards)
            }.onDelete(perform: _state.deleteKeys)
          } header: {
            if _state.list.contains(where: { !$0.isAccessible }) {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                Text("The Private Key component of some identities is missing. The Public Key is still available so  keys can be recycled at the server.")
              }
            }
          } footer: {
            Text("For security reasons, Blink stores Private Keys within protected areas of your device, ensuring their exclusion from iCloud sync and iCloud backups.")
          }.textCase(nil)
        }
      }
    }
    .onAppear {
      if _state.list.isEmpty {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          toggleNewKeyView()
        }
      }
    }
    .listStyle(InsetGroupedListStyle())
    .navigationBarItems(
      trailing: HStack {
        if !_state.list.isEmpty {
          KeySortView(sortType: $_state.sortType)
          
          Button(action: {
            toggleNewKeyView()
          }) {
            Image(systemName: "plus")
              .imageScale(.large)
              .frame(width: 44, height: 44)
          }
        }
      }
    )
    .navigationBarTitle("Keys")
    .fileImporter(
      isPresented: $_state.filePickerIsPresented,
      allowedContentTypes: [.text, .data, .item],
      onCompletion: _state.importFromFile
    )
    .fullScreenCover(isPresented: $isMenuPresented) {
      NewKeyMenuContentView(isMenuPresented: $isMenuPresented, state: _state)
    }
    .sheet(item: $_state.modal) { modal in
      NavigationView {
        switch (modal) {
        case .passphrasePrompt(let keyBlob, let proposedName):
          PassphraseView(
            keyBlob: keyBlob,
            keyProposedName: proposedName,
            onCancel: _state.onModalCancel,
            onSuccess: _state.onModalSuccess
          )
        case .saveImportedKey(let observable):
          ImportKeyView(
            state: observable,
            onCancel: _state.onModalCancel,
            onSuccess: _state.onModalSuccess
          )
        case .newKey:
          NewKeyView(
            onCancel: _state.onModalCancel,
            onSuccess: _state.onModalSuccess
          )
        case .newSEKey:
          NewSEKeyView(
            onCancel: _state.onModalCancel,
            onSuccess: _state.onModalSuccess
          )
        case .newPasskey:
          if #available(iOS 16.0, *) {
            NewPasskeyView(
              onCancel: _state.onModalCancel,
              onSuccess: _state.onModalSuccess
            )
          } else {
            EmptyView()
          }
        case .newSecurityKey:
          if #available(iOS 16.0, *) {
            NewSecurityKeyView(
              onCancel: _state.onModalCancel,
              onSuccess: _state.onModalSuccess
            )
          } else {
            EmptyView()
          }
        }
      }
    }
    .alert(errorMessage: $_state.errorMessage)
  }
  
  //MARK: Fast methods
  func toggleNewKeyView() {
    isMenuPresented.toggle()
  }
}


struct KeyListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView(content: {
      KeyListView()
    })
  }
}


//MARK: - Main Keys Manager
fileprivate class KeysObservable: ObservableObject {
  enum KeySortType {
    case nameAsc, nameDesc, typeAsc, typeDesc, storageAsc, storageDesc

    var sortFn: (_ a: KeyCard, _ b: KeyCard) -> Bool {
      switch self {
      case .nameAsc:     return { a, b in a.name < b.name }
      case .nameDesc:    return { a, b in b.name < a.name }
      case .typeAsc:     return { a, b in a.keyType ?? "" < b.keyType ?? "" }
      case .typeDesc:    return { a, b in b.keyType ?? "" < a.keyType ?? "" }
      case .storageAsc:  return { a, b in a.key.storageType.rawValue < b.key.storageType.rawValue }
      case .storageDesc: return { a, b in b.key.storageType.rawValue < a.key.storageType.rawValue }
      }
    }
  }

  @Published var sortType: KeySortType = .nameAsc {
    didSet {
      list = list.sorted(by: sortType.sortFn)
    }
  }

  @Published var list: [KeyCard] = BKPubKey.all().map(KeyCard.init(key:)).sorted(by: KeySortType.nameAsc.sortFn)
  @Published var actionSheetIsPresented: Bool = false
  @Published var filePickerIsPresented: Bool = false
  @Published var modal: KeyModals? = nil
  var addKeyObservable: ImportKeyObservable? = nil
  @Published var errorMessage = ""
  var proposedKeyName = ""

  init() { }

  func reloadCards() {
    self.list = BKPubKey.all().map(KeyCard.init(key:)).sorted(by: sortType.sortFn)
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
        throw KeyUIError.noReadAccess
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
      let blob = SSHKey.sanitize(key: string).data(using: .utf8)
    else {
      return _showError(message: "Can't convert to data")
    }

    _importKeyFromBlob(blob: blob, proposedKeyName: "")
  }

  func onModalCancel() {
    self.modal = nil
  }

  func onModalSuccess() {
    self.modal = nil
    reloadCards()
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
  }
}

fileprivate enum KeyModals: Identifiable {
  case passphrasePrompt(keyBlob: Data, proposedKeyName: String)
  case saveImportedKey(ImportKeyObservable)
  case newKey
  case newSEKey
  case newPasskey
  case newSecurityKey

  var id: Int {
    switch self {
    case .passphrasePrompt: return 0
    case .saveImportedKey: return 1
    case .newKey: return 2
    case .newSEKey: return 3
    case .newPasskey: return 4
    case .newSecurityKey: return 5
    }
  }
}

extension View {
  func navigatePush(whenTrue toggle: Binding<Bool>) -> some View {
    NavigationLink(destination: self, isActive: toggle) { EmptyView() }
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


extension BKPubKeyStorageType {
  public func shortName() -> String {
    switch self {
    case BKPubKeyStorageTypeKeyChain: return "Keychain"
    case BKPubKeyStorageTypeSecureEnclave: return "SE"
    case BKPubKeyStorageTypeiCloudKeyChain: return "iCloud Keychain"
    case BKPubKeyStorageTypeSecurityKey: return "SK"
    case BKPubKeyStorageTypePlatformKey: return "Passkey"
    default:
      return ""
    }
  }
}
