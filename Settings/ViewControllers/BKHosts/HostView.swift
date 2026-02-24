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

import CloudKit
import Combine
import SwiftUI

import BlinkFileProvider

struct FileDomainView: View {
  @EnvironmentObject private var _nav: Nav
  var domain: FileProviderDomain
  var hostAlias: String
  let refreshList: () -> ()
  let saveHost: () -> ()
  @State private var _displayName: String = ""
  @State private var _remotePath: String = ""
  @State private var _loaded = false
  @State private var _errorMessage = ""

  @State private var showValidateConnectionProgress = false
  @State private var validateConnectionCompletion: Subscribers.Completion<ValidationError>? = nil
  @State private var validateConnectionCancellable: AnyCancellable? = nil

  var body: some View {
    List {
      Section {
        Field("Name", $_displayName, next: "Path", placeholder: "Required")
        Field("Path", $_remotePath,  next: "",     placeholder: "root folder on the remote")
      }
      Section(footer: Text("Validating the connection will save all changes made.")) {
        Button("Validate Connection", action: {
          _testConnection()
        })
          .alert(isPresented: $showValidateConnectionProgress) {
            if let completion = validateConnectionCompletion {
              switch completion {
              case .finished:
                return Alert(
                  title: Text("Validating Connection Succeded"),
                  message: Text("Connection tested successfully."),
                  dismissButton: .default(Text("Dismiss"))
                )
              case .failure(let error):
                return Alert(
                  title: Text("Validating Connection Failed"),
                  message: Text(error.localizedDescription),
                  dismissButton: .default(Text("Dismiss"))
                )
              }
            } else {
              return Alert(
                title: Text("Validating Connection"),
                message: Text("Connecting to remote..."),
                // message: Text(validateConnectionProgressMessage),
                dismissButton: .cancel(Text("Cancel"), action: { self.validateConnectionCancellable = nil })
              )
            }
          }
      }
      // Disabled for now. Although the cached can be erased, the cache in memory will still remain and that
      // will mess with state. Deleting the domain itself is the way to go.
//      Section {
//        Button(
//          action: _eraseCache,
//          label: { Label("Erase location cache", systemImage: "trash").foregroundColor(.red)}
//        )
//          .accentColor(.red)
//      }
    }
    .listStyle(GroupedListStyle())
    .navigationBarTitle("Files.app Location")
    .navigationBarItems(
      trailing: Group {
        Button("Update", action: {
          guard _validate() else { return }
          _updateDomain()
          refreshList()
          _nav.navController.popViewController(animated: true)
        }
        )//.disabled(_conflictedICloudHost != nil)
      }
    )
    .onAppear {
      if !_loaded {
        _loaded = true
        _displayName = domain.displayName
        _remotePath = domain.remotePath
      }
    }
    .alert(errorMessage: $_errorMessage)
  }

  private func _updateDomain() {
    domain.displayName = _displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    domain.remotePath = _remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
    domain.useReplicatedExtension = true
  }

  private func _validate() -> Bool {
    let cleanDisplayName = _displayName.trimmingCharacters(in: .whitespacesAndNewlines)

    do {
      if cleanDisplayName.isEmpty {
        throw ValidationError.general(message: "Name is required", field: "Name")
      }
      return true
    } catch {
      _errorMessage = error.localizedDescription
      return false
    }
  }

  private func _testConnection() {
    guard _validate() else { return }
    _updateDomain()
    saveHost()

    let providerPath: BlinkFileProviderPath
    do {
      providerPath = try BlinkFileProviderPath(domain.connectionPathFor(alias: hostAlias))
    } catch {
      _errorMessage = "Could not resolve domain path."
      return
    }

    let conn = FilesTranslatorConnection(providerPath: providerPath,
                                         configurator: BlinkConfigFactoryConfiguration())
    self.validateConnectionCancellable = nil
    self.validateConnectionCompletion = nil
    // self.isValidatingConnection = true
    self.showValidateConnectionProgress = true

    self.validateConnectionCancellable = conn.rootTranslator
      .mapError { error in ValidationError.connection(message: "Connection error: \(error)") }
      .sink(
        receiveCompletion: {
          self.validateConnectionCompletion = $0
          //self.showValidateConnectionProgress = false
        },
        receiveValue: { _ in }
      )
  }
//  private func _eraseCache() {
//    if let nsDomain = domain.nsFileProviderDomain(alias: alias) {
//      _NSFileProviderManager.clearFileProviderCache(nsDomain)
//    }
//  }
}

fileprivate struct FileDomainRow: View {
  let domain: FileProviderDomain
  let alias: String
  let refreshList: () -> ()
  let saveHost: () -> ()

  var body: some View {
    Row(
      content: {
        HStack {
          if !domain.useReplicatedExtension {
            Text("DEPRECATED")
              .font(.footnote)
              .padding(6)
              .background(Color.red.opacity(0.3))
              .cornerRadius(8)
              .frame(maxHeight: .infinity)
          }
          Text(domain.displayName)
          Spacer()
          Text(domain.remotePath).font(.system(.subheadline))
        }
      },
      details: {
        FileDomainView(domain: domain, hostAlias: alias, refreshList: refreshList, saveHost: saveHost)
      }
    )
  }
}

struct FormLabel: View {
  let text: String
  var minWidth: CGFloat = 86

  var body: some View {
    Text(text).frame(minWidth: minWidth, alignment: .leading)
  }
}

struct Field: View {
  private let _id: String
  private let _label: String
  private let _placeholder: String
  @Binding private var value: String
  private let _next: String?
  private let _secureTextEntry: Bool
  private let _enabled: Bool
  private let _kbType: UIKeyboardType

  init(_ label: String, _ value: Binding<String>, next: String, placeholder: String, id: String? = nil, secureTextEntry: Bool = false, enabled: Bool = true, kbType: UIKeyboardType = .default) {
    _id = id ?? label
    _label = label
    _value = value
    _placeholder = placeholder
    _next = next
    _secureTextEntry = secureTextEntry
    _enabled = enabled
    _kbType = kbType
  }

  var body: some View {
    HStack {
      FormLabel(text: _label)
      FixedTextField(
        _placeholder,
        text: $value,
        id: _id,
        nextId: _next,
        secureTextEntry: _secureTextEntry,
        keyboardType: _kbType,
        autocorrectionType: .no,
        autocapitalizationType: .none,
        enabled: _enabled
      )
    }
  }
}

struct FieldPassword: View {
  private let _label: String
  private let _placeholder: String
  @Binding private var value: String
  private let _next: String?
  private let _enabled: Bool
  @State private var _showPassword: Bool = false

  init(_ label: String, _ value: Binding<String>, next: String, placeholder: String, enabled: Bool = true) {
    _label = label
    _value = value
    _placeholder = placeholder
    _next = next
    _enabled = enabled
  }

  var body: some View {
    HStack {
      FormLabel(text: _label)
      FixedTextField(
        _placeholder,
        text: $value,
        id: _label,
        nextId: _next,
        secureTextEntry: !_showPassword,
        keyboardType: .default,
        autocorrectionType: .no,
        autocapitalizationType: .none,
        enabled: _enabled
      )
      Button(action: {
        _showPassword.toggle()
      }) {
        Image(systemName: _showPassword ? "eye.slash.fill" : "eye.fill")
          .foregroundColor(.secondary)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(!_enabled)
    }
  }
}

struct FieldSSHKey: View {
  @Binding var value: [String]
  var enabled: Bool = true
  var hasSSHKey: Bool

  var body: some View {
    Row(
      content: {
        HStack {
          if (hasSSHKey || value.isEmpty) {
            FormLabel(text: "Key")
            Spacer()
            Text(value.isEmpty ? "None" : value[0])
              .font(.system(.subheadline)).foregroundColor(.secondary)
          } else {
            Label("Key", systemImage: "exclamationmark.icloud.fill")
            Spacer()
            Text(value[0])
              .font(.system(.subheadline)).foregroundColor(.red)
          }
        }
      },
      details: {
        KeyPickerView(currentKey: enabled ? $value : .constant(value), multipleSelection: false)
      }
    )
  }
}


fileprivate struct FieldMoshCustomOptions: View {
  @Binding var prediction: BKMoshPrediction
  @Binding var overwrite: Bool
  @Binding var experimentalIP: BKMoshExperimentalIP
  var enabled: Bool

  var body: some View {
    Row(
      content: {
        HStack {
          FormLabel(text: "Advanced")
          Spacer()
          //Text(prediction.label + "...").font(.system(.subheadline)).foregroundColor(.secondary)
        }
      },
      details: {
        MoshCustomOptionsPickerView(
          predictionValue: enabled ? $prediction : .constant(prediction),
          overwriteValue: enabled ? $overwrite : .constant(overwrite),
          experimentalIPValue: enabled ? $experimentalIP : .constant(experimentalIP)
        )
      }
    )
  }
}

fileprivate struct FieldAgentForwardPrompt: View {
  @Binding var value: BKAgentForward
  var enabled: Bool

  var body: some View {
    Row(
      content: {
        HStack {
          FormLabel(text: "Agent Forwarding")
          Spacer()
          Text(value.label).font(.system(.subheadline)).foregroundColor(.secondary)
        }
      },
      details: {
        AgentForwardPromptPickerView(
          currentValue: enabled ? $value : .constant(value)
        )
      }
    )
  }
}

fileprivate struct FieldAgentForwardKeys: View {
  @Binding var value: [String]
  var enabled: Bool

  var body: some View {
    Row(
      content: {
        HStack {
          FormLabel(text: "Forward Keys")
          Spacer()
          Text(value.isEmpty ? "None" : value.joined(separator: ", "))
            .font(.system(.subheadline)).foregroundColor(.secondary)
        }
      },
      details: {
        KeyPickerView(currentKey: enabled ? $value : .constant(value), multipleSelection: true)
      }
    ).disabled(!enabled)
  }
}

struct FieldTextArea: View {
  private let _label: String
  @Binding private var value: String
  private let _enabled: Bool

  init(_ label: String, _ value: Binding<String>, enabled: Bool = true) {
    _label = label
    _value = value
    _enabled = enabled
  }

  var body: some View {
    Row(
      content: { FormLabel(text: _label) },
      details: {
        // TextEditor can't change background color
        RoundedRectangle(cornerRadius: 4, style: .circular)
          .fill(Color.primary)
          .overlay(
            TextEditor(text: _value)
              .font(.system(.body))
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .opacity(0.9).disabled(!_enabled)
          )
          .padding()
        .navigationTitle(_label)
        .navigationBarTitleDisplayMode(.inline)
      }
    )
  }
}

struct HostView: View {
  @EnvironmentObject private var _nav: Nav

  @State private var _host: BKHosts?
  private var _duplicatedHost: BKHosts? = nil
  @State private var _conflictedICloudHost: BKHosts? = nil
  @State private var _alias: String = ""
  @State private var _hostName: String = ""
  @State private var _port: String = ""
  @State private var _user: String = ""
  @State private var _password: String = ""
  @State private var _sshKeyName: [String] = []
  @State private var _proxyCmd: String = ""
  @State private var _proxyJump: String = ""
  @State private var _sshConfigAttachment: String = HostView.__sshConfigAttachmentExample

  @State private var _moshServer: String = ""
  @State private var _moshPort: String = ""
  @State private var _moshPrediction: BKMoshPrediction = BKMoshPredictionAdaptive
  @State private var _moshPredictOverwrite: Bool = false
  @State private var _moshExperimentalIP: BKMoshExperimentalIP = BKMoshExperimentalIPNone
  @State private var _moshCommand: String = ""
  @State private var _domains: [FileProviderDomain] = []
  @State private var _domainsListVersion = 0;
  @State private var _loaded = false
  @State private var _enabled: Bool = true

  @State private var _agentForwardPrompt: BKAgentForward = BKAgentForwardNo
  @State private var _agentForwardKeys: [String] = []

  @State private var _errorMessage: String = ""

  private var _iCloudVersion: Bool
  private var _reloadList: () -> ()
  private var _cleanAlias: String {
    _alias.trimmingCharacters(in: .whitespacesAndNewlines)
  }


  init(host: BKHosts?, iCloudVersion: Bool = false, reloadList: @escaping () -> ()) {
    _host = host
    _iCloudVersion = iCloudVersion
    _conflictedICloudHost = host?.iCloudConflictCopy
    _reloadList = reloadList
  }

  init(duplicatingHost host: BKHosts, reloadList: @escaping () -> ()) {
    _host = nil
    _duplicatedHost = host
    _iCloudVersion = false
    _conflictedICloudHost = nil
    _reloadList = reloadList
  }

  private func _usageHint() -> String {
    var alias = _cleanAlias
    if alias.count < 2 {
      alias = "[alias]"
    }

    return "Use `mosh \(alias)` or `ssh \(alias)` from the shell to connect."
  }

  var body: some View {
    List {
      if let iCloudCopy = _conflictedICloudHost {
        Section(
          header: Label("CONFLICT DETECTED", systemImage: "exclamationmark.icloud.fill"),
          footer: Text("A conflict has been detected. Please choose a version to save to continue.").foregroundColor(.red)
        ) {
          Row(
            content: { Label("iCloud Version", systemImage: "icloud") },
            details: {
              HostView(host: iCloudCopy, iCloudVersion: true, reloadList: _reloadList)
            }
          )
          Button(
            action: {
              _saveICloudVersion()
              _nav.navController.popViewController(animated: true)
            },
            label: { Label("Save iCloud Version", systemImage: "icloud.and.arrow.down") }
          )
          Button(
            action: {
              _saveLocalVersion()
              _nav.navController.popViewController(animated: true)
            },
            label: { Label("Save Local Version", systemImage: "icloud.and.arrow.up") }
          )
        }
      }
      Section(
        header: Text(_conflictedICloudHost == nil ? "" : "Local Verion"),
        footer: Text(verbatim: _usageHint())
      ) {
        Field("Alias", $_alias, next: "HostName", placeholder: "Required")
      }.disabled(!_enabled)

      Section(header: Text("SSH")) {
        Field("HostName",  $_hostName,  next: "Port",      placeholder: "Host or IP address. Required", enabled: _enabled, kbType: .URL)
        Field("Port",      $_port,      next: "User",      placeholder: "22", enabled: _enabled, kbType: .numberPad)
        Field("User",      $_user,      next: "Password",  placeholder: BLKDefaults.defaultUserName(), enabled: _enabled)
        FieldPassword("Password",  $_password,  next: "ProxyCmd",  placeholder: "Ask Every Time", enabled: _enabled)
        FieldSSHKey(value: $_sshKeyName, enabled: _enabled, hasSSHKey: BKPubKey.all().contains(where: {
          if let keyName = _sshKeyName.first {
            return $0.id == keyName
          }
          return false
        }))
        Field("ProxyCmd",  $_proxyCmd,  next: "ProxyJump", placeholder: "ssh -W %h:%p bastion", enabled: _enabled)
        Field("ProxyJump", $_proxyJump, next: "Server",    placeholder: "bastion1,bastion2", enabled: _enabled)
        FieldTextArea("SSH Config", $_sshConfigAttachment, enabled: _enabled)
      }

      Section(
        header: Text("MOSH")
      ) {
        Field("Server",  $_moshServer,  next: "moshPort",    placeholder: "path/to/mosh-server")
        Field("Port",    $_moshPort,    next: "moshCommand", placeholder: "UDP PORT[:PORT2]", id: "moshPort", kbType: .numbersAndPunctuation)
        Field("Command", $_moshCommand, next: "Alias",       placeholder: "screen -r or tmux attach", id: "moshCommand")
        FieldMoshCustomOptions(
          prediction: $_moshPrediction,
          overwrite: $_moshPredictOverwrite,
          experimentalIP: $_moshExperimentalIP,
          enabled: _enabled
        )
      }.disabled(!_enabled)

      Section(
        header: Text("SSH AGENT")
      ) {
        FieldAgentForwardPrompt(value: $_agentForwardPrompt, enabled: _enabled)
        if _agentForwardPrompt != BKAgentForwardNo {
          FieldAgentForwardKeys(value: $_agentForwardKeys, enabled: _enabled)
        }
      }.disabled(!_enabled)

      Section(header: Label("Files.app", systemImage: "folder"),
              footer: Text("Access remote file systems from the Files.app. [Learn More](https://docs.blink.sh/advanced/files-app)")) {
        ForEach(_domains, content: { FileDomainRow(domain: $0, alias: _cleanAlias, refreshList: _refreshDomainsList, saveHost: _saveHost) })
          .onDelete { indexSet in
            _domains.remove(atOffsets: indexSet)
          }
        Button(
          action: {
            let displayName = _cleanAlias
            _domains.append(FileProviderDomain(
              id:UUID(),
              displayName: displayName.isEmpty ? "Location Name" : displayName,
              remotePath: "~",
              proto: "sftp",
              useReplicatedExtension: true
            ))
          },
          label: { Label("Add Location", systemImage: "folder.badge.plus") }
        )
      }
      .id(_domainsListVersion)
      .disabled(!_enabled)
    }
    .listStyle(GroupedListStyle())
    .alert(errorMessage: $_errorMessage)
    .navigationBarItems(
      leading: Group {
        Button("Discard", action: {
          _nav.navController.popViewController(animated: true)
        })
      },
      trailing: Group {
        if !_iCloudVersion {
          Button("Save", action: {
            _validate()
            _saveHost()
            _reloadList()
            _nav.navController.popViewController(animated: true)
          }).disabled(_conflictedICloudHost != nil)
        }
      }
    )
    .navigationBarBackButtonHidden(true)
    .navigationBarTitle(_host == nil ? "New Host" : _iCloudVersion ? "iCloud Host Version" : "Host" )
    .onAppear {
      if !_loaded {
        loadHost()
      }
    }

  }

  private static var __sshConfigAttachmentExample: String { "# Compression no" }

  func loadHost() {
    _loaded = true

    guard let host = _host ?? _duplicatedHost else {
      return
    }

    _alias = host.host ?? ""
    _hostName = host.hostName ?? ""
    _port = host.port == nil ? "" : host.port.stringValue
    _user = host.user ?? ""
    _password = host.password ?? ""
    _sshKeyName = (host.key == nil || host.key.isEmpty) ? [] : [host.key]
    _proxyCmd = host.proxyCmd ?? ""
    _proxyJump = host.proxyJump ?? ""
    _sshConfigAttachment = host.sshConfigAttachment ?? ""
    if _sshConfigAttachment.isEmpty {
      _sshConfigAttachment = HostView.__sshConfigAttachmentExample
    }
    if let moshPort = host.moshPort {
      if let moshPortEnd = host.moshPortEnd {
        _moshPort = "\(moshPort):\(moshPortEnd)"
      } else {
        _moshPort = moshPort.stringValue
      }
    }

    _moshPrediction.rawValue = UInt32(host.prediction?.intValue ?? 0)
    _moshPredictOverwrite = host.moshPredictOverwrite == "yes"
    _moshExperimentalIP.rawValue = UInt32(host.moshExperimentalIP?.intValue ?? 0)
    _moshServer  = host.moshServer ?? ""
    _moshCommand = host.moshStartup ?? ""
    _agentForwardPrompt.rawValue = UInt32(host.agentForwardPrompt?.intValue ?? 0)
    _agentForwardKeys = host.agentForwardKeys ?? []
    _enabled = !( _conflictedICloudHost != nil || _iCloudVersion)

    if _duplicatedHost == nil {
      _domains = FileProviderDomain.listFrom(jsonString: host.fpDomainsJSON)
    }
  }

  private func _validate() {
    let cleanAlias = _cleanAlias

    do {
      if cleanAlias.isEmpty {
        throw ValidationError.general(
          message: "Alias is required."
        )
      }

      if let _ = cleanAlias.rangeOfCharacter(from: .whitespacesAndNewlines) {
        throw ValidationError.general(
          message: "Spaces are not permitted in the alias."
        )
      }

      if let _ = BKHosts.withHost(cleanAlias), cleanAlias != _host?.host {
        throw ValidationError.general(
          message: "Cannot have two hosts with the same alias."
        )
      }

      let cleanHostName = _hostName.trimmingCharacters(in: .whitespacesAndNewlines)
      if let _ = cleanHostName.rangeOfCharacter(from: .whitespacesAndNewlines) {
        throw ValidationError.general(message: "Spaces are not permitted in the host name.")
      }

      if cleanHostName.isEmpty {
        throw ValidationError.general(
          message: "HostName is required."
        )
      }
    } catch {
      _errorMessage = error.localizedDescription
      return
    }
  }

  private func _saveHost() {
    let savedHost = BKHosts.saveHost(
      _host?.host.trimmingCharacters(in: .whitespacesAndNewlines),
      withNewHost: _cleanAlias,
      hostName: _hostName.trimmingCharacters(in: .whitespacesAndNewlines),
      sshPort: _port.trimmingCharacters(in: .whitespacesAndNewlines),
      user: _user.trimmingCharacters(in: .whitespacesAndNewlines),
      password: _password,
      hostKey: _sshKeyName.isEmpty ? "" : _sshKeyName[0],
      moshServer: _moshServer,
      moshPredictOverwrite: _moshPredictOverwrite ? "yes" : nil,
      moshExperimentalIP: _moshExperimentalIP,
      moshPortRange: _moshPort,
      startUpCmd: _moshCommand,
      prediction: _moshPrediction,
      proxyCmd: _proxyCmd,
      proxyJump: _proxyJump,
      sshConfigAttachment: _sshConfigAttachment == HostView.__sshConfigAttachmentExample ? "" : _sshConfigAttachment,
      fpDomainsJSON: FileProviderDomain.toJson(list: _domains),
      agentForwardPrompt: _agentForwardPrompt,
      agentForwardKeys: _agentForwardPrompt == BKAgentForwardNo ? [] : _agentForwardKeys
    )

    guard let host = savedHost else {
      return
    }

    BKHosts.updateHost(host.host, withiCloudId: host.iCloudRecordId, andLastModifiedTime: Date())
    BKiCloudSyncHandler.shared()?.check(forReachabilityAndSync: nil)
    #if targetEnvironment(macCatalyst)
    #else
    _NSFileProviderManager.syncWithBKHosts()
    #endif
  }

  private func _saveICloudVersion() {
    guard
      let host = _host,
      let iCloudHost = host.iCloudConflictCopy,
      let syncHandler = BKiCloudSyncHandler.shared()
    else {
      return
    }

    if let recordId = host.iCloudRecordId {
      syncHandler.deleteRecord(recordId, of: BKiCloudRecordTypeHosts)
    }
    let moshPort = iCloudHost.moshPort
    let moshPortEnd = iCloudHost.moshPortEnd

    var moshPortRange = moshPort?.stringValue ?? ""
    if let moshPort = moshPort, let moshPortEnd = moshPortEnd {
      moshPortRange = "\(moshPort):\(moshPortEnd)"
    }

    BKHosts.saveHost(
      host.host,
      withNewHost: iCloudHost.host,
      hostName: iCloudHost.hostName,
      sshPort: iCloudHost.port?.stringValue ?? "",
      user: iCloudHost.user,
      password: iCloudHost.password,
      hostKey: iCloudHost.key,
      moshServer: iCloudHost.moshServer,
      moshPredictOverwrite: iCloudHost.moshPredictOverwrite,
      moshExperimentalIP: BKMoshExperimentalIP(UInt32(iCloudHost.moshExperimentalIP?.intValue ?? 0)),
      moshPortRange: moshPortRange,
      startUpCmd: iCloudHost.moshStartup,
      prediction: BKMoshPrediction(UInt32(iCloudHost.prediction?.intValue ?? 0)),
      proxyCmd: iCloudHost.proxyCmd,
      proxyJump: iCloudHost.proxyJump,
      sshConfigAttachment: iCloudHost.sshConfigAttachment,
      fpDomainsJSON: iCloudHost.fpDomainsJSON,
      agentForwardPrompt: BKAgentForward(UInt32(iCloudHost.agentForwardPrompt?.intValue ?? 0)),
      agentForwardKeys: iCloudHost.agentForwardKeys
    )

    BKHosts.updateHost(
      iCloudHost.host,
      withiCloudId: iCloudHost.iCloudRecordId,
      andLastModifiedTime: iCloudHost.lastModifiedTime
    )

    BKHosts.markHost(iCloudHost.host, for: BKHosts.record(fromHost: host), withConflict: false)
    syncHandler.check(forReachabilityAndSync: nil)

    _NSFileProviderManager.syncWithBKHosts()
  }

  private func _saveLocalVersion() {
    guard let host = _host, let syncHandler = BKiCloudSyncHandler.shared()
    else {
      return
    }
    syncHandler.deleteRecord(host.iCloudConflictCopy.iCloudRecordId, of: BKiCloudRecordTypeHosts)
    if (host.iCloudRecordId == nil) {
      BKHosts.markHost(host.iCloudConflictCopy.host, for: BKHosts.record(fromHost: host), withConflict: false)
    }
    syncHandler.check(forReachabilityAndSync: nil)
  }

  private func _refreshDomainsList() {
    _domainsListVersion += 1
  }
}

fileprivate enum ValidationError: Error, LocalizedError {
  case general(message: String, field: String? = nil)
  case connection(message: String)

  var errorDescription: String? {
    switch self {
    case .general(message: let message, field: _): return message
    case .connection(message: let message): return message
    }
  }
}
