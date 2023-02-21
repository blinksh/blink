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
import CloudKit

struct FileDomainView: View {
  @EnvironmentObject private var _nav: Nav
  var domain: FileProviderDomain
  var alias: String
  let refreshList: () -> ()
  @State private var _displayName: String = ""
  @State private var _remotePath: String = ""
  @State private var _loaded = false
  @State private var _errorMessage = ""
  
  var body: some View {
    List {
      Section {
        Field("Name", $_displayName, next: "Path", placeholder: "Required")
        Field("Path", $_remotePath,  next: "",     placeholder: "root folder on the remote")
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
          do  {
            try _validate()
          } catch {
            _errorMessage = error.localizedDescription
            return
          }
          domain.displayName = _displayName.trimmingCharacters(in: .whitespacesAndNewlines)
          domain.remotePath = _remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
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
  
  private func _validate() throws {
    let cleanDisplayName = _displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if cleanDisplayName.isEmpty {
      throw FormValidationError.general(message: "Name is required", field: "Name")
    }
  }
  
  private func _eraseCache() {
    if let nsDomain = domain.nsFileProviderDomain(alias: alias) {
      _NSFileProviderManager.clearFileProviderCache(nsDomain)
    }
  }
}

fileprivate struct FileDomainRow: View {
  let domain: FileProviderDomain
  let alias: String
  let refreshList: () -> ()
  
  var body: some View {
    Row(
      content: {
        HStack {
          Text(domain.displayName)
          Spacer()
          Text(domain.remotePath).font(.system(.subheadline))
        }
      },
      details: {
        FileDomainView(domain: domain, alias: alias, refreshList: refreshList)
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

struct FieldSSHKey: View {
  @Binding var value: String
  var enabled: Bool = true
  
  var body: some View {
    Row(
      content: {
        HStack {
          FormLabel(text: "Key")
          Spacer()
          Text(value.isEmpty ? "None" : value)
            .font(.system(.subheadline)).foregroundColor(.secondary)
        }
      },
      details: {
        KeyPickerView(currentKey: enabled ? $value : .constant(value))
      }
    )
  }
}


fileprivate struct FieldMoshPrediction: View {
  @Binding var value: BKMoshPrediction
  @Binding var overwriteValue: Bool
  var enabled: Bool
  
  var body: some View {
    Row(
      content: {
        HStack {
          FormLabel(text: "Prediction")
          Spacer()
          Text(value.label).font(.system(.subheadline)).foregroundColor(.secondary)
        }
      },
      details: {
        MoshPredictionPickerView(
          currentValue: enabled ? $value : .constant(value),
          overwriteValue: enabled ? $overwriteValue : .constant(overwriteValue)
        )
      }
    )
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
  @State private var _conflictedICloudHost: BKHosts? = nil
  @State private var _alias: String = ""
  @State private var _hostName: String = ""
  @State private var _port: String = ""
  @State private var _user: String = ""
  @State private var _password: String = ""
  @State private var _sshKeyName: String = ""
  @State private var _proxyCmd: String = ""
  @State private var _proxyJump: String = ""
  @State private var _sshConfigAttachment: String = HostView.__sshConfigAttachmentExample
  
  @State private var _moshServer: String = ""
  @State private var _moshPort: String = ""
  @State private var _moshPrediction: BKMoshPrediction = BKMoshPredictionAdaptive
  @State private var _moshPredictOverwrite: Bool = false
  @State private var _moshCommand: String = ""
  @State private var _domains: [FileProviderDomain] = []
  @State private var _domainsListVersion = 0;
  @State private var _loaded = false
  @State private var _enabled: Bool = true
  
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
        Field("Password",  $_password,  next: "ProxyCmd",  placeholder: "Ask Every Time", secureTextEntry: true, enabled: _enabled)
        FieldSSHKey(value: $_sshKeyName, enabled: _enabled)
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
        FieldMoshPrediction(
          value: $_moshPrediction,
          overwriteValue: $_moshPredictOverwrite,
          enabled: _enabled
        )
      }.disabled(!_enabled)
      
      Section(header: Label("Files.app", systemImage: "folder")) {
        ForEach(_domains, content: { FileDomainRow(domain: $0, alias: _cleanAlias, refreshList: _refreshDomainsList) })
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
              proto: "sftp"
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
      trailing: Group {
        if !_iCloudVersion {
          Button("Save", action: {
            do  {
              try _validate()
            } catch {
              _errorMessage = error.localizedDescription
              return
            }
            _saveHost()
            _reloadList()
            _nav.navController.popViewController(animated: true)
          }).disabled(_conflictedICloudHost != nil)
        }
      }
    )
    .navigationBarTitle(_host == nil ? "New Host" : _iCloudVersion ? "iCloud Host Version" : "Host" )
    .onAppear {
      if !_loaded {
        loadHost()
        _loaded = true
      }
    }
    
  }
  
  private static var __sshConfigAttachmentExample: String { "# Compression no" }
  
  func loadHost() {
    if let host = _host {
      _alias = host.host ?? ""
      _hostName = host.hostName ?? ""
      _port = host.port == nil ? "" : host.port.stringValue
      _user = host.user ?? ""
      _password = host.password ?? ""
      _sshKeyName = host.key ?? ""
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

      _moshPrediction.rawValue = UInt32(host.prediction.intValue)
      _moshPredictOverwrite = host.moshPredictOverwrite == "yes"
      _moshServer  = host.moshServer ?? ""
      _moshCommand = host.moshStartup ?? ""
      _domains = FileProviderDomain.listFrom(jsonString: host.fpDomainsJSON)
      _enabled = !( _conflictedICloudHost != nil || _iCloudVersion)
    }
  }
  
  private func _validate() throws {
    let cleanAlias = _cleanAlias
    
    if cleanAlias.isEmpty {
      throw FormValidationError.general(
        message: "Alias is required."
      )
    }
    
    if let _ = cleanAlias.rangeOfCharacter(from: .whitespacesAndNewlines) {
      throw FormValidationError.general(
        message: "Spaces are not permitted in the alias."
      )
    }
    
    if let _ = BKHosts.withHost(cleanAlias), cleanAlias != _host?.host {
      throw FormValidationError.general(
        message: "Cannot have two hosts with the same alias."
      )
    }
    
    let cleanHostName = _hostName.trimmingCharacters(in: .whitespacesAndNewlines)
    if let _ = cleanHostName.rangeOfCharacter(from: .whitespacesAndNewlines) {
      throw FormValidationError.general(message: "Spaces are not permitted in the host name.")
    }
    
    if cleanHostName.isEmpty {
      throw FormValidationError.general(
        message: "HostName is required."
      )
    }
    
    let cleanUser = _user.trimmingCharacters(in: .whitespacesAndNewlines)
    if let _ = cleanUser.rangeOfCharacter(from: .whitespacesAndNewlines) {
      throw FormValidationError.general(message: "Spaces are not permitted in the user name.")
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
      hostKey: _sshKeyName,
      moshServer: _moshServer,
      moshPredictOverwrite: _moshPredictOverwrite ? "yes" : nil,
      moshPortRange: _moshPort,
      startUpCmd: _moshCommand,
      prediction: _moshPrediction,
      proxyCmd: _proxyCmd,
      proxyJump: _proxyJump,
      sshConfigAttachment: _sshConfigAttachment == HostView.__sshConfigAttachmentExample ? "" : _sshConfigAttachment,
      fpDomainsJSON: FileProviderDomain.toJson(list: _domains)
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
      moshPortRange: moshPortRange,
      startUpCmd: iCloudHost.moshStartup,
      prediction: BKMoshPrediction(UInt32(iCloudHost.prediction?.intValue ?? 0)),
      proxyCmd: iCloudHost.proxyCmd,
      proxyJump: iCloudHost.proxyJump,
      sshConfigAttachment: iCloudHost.sshConfigAttachment,
      fpDomainsJSON: iCloudHost.fpDomainsJSON
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

enum FormValidationError: Error, LocalizedError {
  case general(message: String, field: String? = nil)
  
  var errorDescription: String? {
    switch self {
    case .general(message: let message, field: _): return message
    }
  }
}

