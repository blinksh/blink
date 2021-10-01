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

class FileProviderDomain: Identifiable, Codable, Equatable {
  static func == (lhs: FileProviderDomain, rhs: FileProviderDomain) -> Bool {
    lhs.id == rhs.id &&
      lhs.displayName == rhs.displayName &&
      lhs.remotePath == rhs.remotePath &&
      lhs.proto == rhs.proto
  }
  
  var id: UUID
  var displayName: String
  var remotePath: String
  var proto: String
  
  init(id: UUID, displayName: String, remotePath: String, proto: String) {
    self.id = id
    self.displayName = displayName
    self.remotePath = remotePath
    self.proto = proto
  }
  
  func nsFileProviderDomain(alias: String) -> NSFileProviderDomain? {
    NSFileProviderDomain(
      identifier: NSFileProviderDomainIdentifier(rawValue: id.uuidString),
      displayName: displayName,
      pathRelativeToDocumentStorage: encodedPathFor(alias: alias) ?? ""
    )
  }
  
  func encodedPathFor(alias: String) -> String? {
    "\(proto):\(alias):\(remotePath)".data(using: .utf8)?.base64EncodedString() ?? ""
  }
  
  static func listFrom(jsonString: String?) -> [FileProviderDomain] {
    guard
      let str = jsonString,
      !str.isEmpty,
      let data = str.data(using: .utf8),
      let arr = try? JSONDecoder().decode([FileProviderDomain].self, from: data)
    else {
      return []
    }
    
    return arr
  }
  
  static func toJson(list: [FileProviderDomain]) -> String {
    guard !list.isEmpty else {
      return ""
    }
    
    let data = try? JSONEncoder().encode(list)
    guard
      let data = data,
      let str = String(data: data, encoding: .utf8)
    else {
      return ""
    }
    
    return str
  }
  
  static func _syncDomainsForAllHosts(nsDomains: [NSFileProviderDomain]) {
    var domainsMap = [String : (alias: String, domain: FileProviderDomain)]()
    var hostsMap = [String : BKHosts]()
    var keysMap = [String : BKPubKey]()
    
    for host in BKHosts.allHosts() {
      guard let json = host.fpDomainsJSON, !json.isEmpty
      else {
        continue
      }
      
      let domains = FileProviderDomain.listFrom(jsonString: json)
      for domain in domains {
        domainsMap[domain.id.uuidString] = (alias: host.host, domain: domain)
      }
      
      if hostsMap[host.host] == nil {
        hostsMap[host.host] = host
        if let key = host.key, !key.isEmpty, key != "None", let sshKey = BKPubKey.withID(key) {
          keysMap[key] = sshKey
        }
      }
    }

    var domainsToRemove: [NSFileProviderDomain] = []
    for d in nsDomains {
      if let blinkDomain = domainsMap.removeValue(forKey: d.identifier.rawValue) {
        if blinkDomain.domain.displayName != d.displayName ||
           blinkDomain.domain.encodedPathFor(alias: blinkDomain.alias) != d.pathRelativeToDocumentStorage {
          domainsToRemove.append(d)
          domainsMap[d.identifier.rawValue] = blinkDomain
        }
      } else {
        domainsToRemove.append(d)
      }
    }
    
    for nsDomain in domainsToRemove {
      NSFileProviderManager.remove(nsDomain) { err in
        if let err = err {
          print("failed to remove domain", err)
        }
      }
    }
    
    for (_, value) in domainsMap {
      if let domain = value.domain.nsFileProviderDomain(alias: value.alias) {
        NSFileProviderManager.add(domain) { err in
          if let err = err {
            print("failed to add domain", err)
          }
        }
      }
    }
  }
}

extension NSFileProviderManager {
  @objc static func syncWithBKHosts() {
    guard FeatureFlags.fileProviders
    else {
      return
    }
    getDomainsWithCompletionHandler { nsDomains, err in
      guard err == nil else {
        print("get domains error", err!)
        return
      }
      FileProviderDomain._syncDomainsForAllHosts(nsDomains: nsDomains)
    }
  }
}
