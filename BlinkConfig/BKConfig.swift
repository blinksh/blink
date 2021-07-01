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
import SSH

public struct BKConfig {
  
  private let _allHosts: [BKHosts]
  private let _allIdentities: [BKPubKey]
  
  public init(allHosts: [BKHosts], allIdentities: [BKPubKey]) {
    _allHosts = allHosts
    _allIdentities = allIdentities
  }

  public func privateKey(forIdentifier identifier: String) -> (String, String)? {
    let publicKeys = BKPubKey.all()
    
    guard
      let privateKey = publicKeys.first(where: { $0.id == identifier })?.loadPrivateKey()
    else {
      return nil
    }
    
    return (privateKey, identifier)
  }
  
  private func _host(_ host: String) -> BKHosts? {
    return _allHosts.first(where: { $0.host == host })
  }
  
  public func signer(forIdentity identity: String) -> (Signer, String)? {
    guard
      let signer = _allIdentities.signerWithID(identity)
    else {
      return nil
    }
    
    return (signer, identity)
  }
  
  public func signer(forHost host: String) -> (Signer, String)? {
    guard
      let host = _host(host),
      let keyName = host.key
    else {
      return nil
    }
    
    return signer(forIdentity: keyName)
  }
  
  public func privateKey(forHost host: String) -> (String, String)? {
    guard let host = _host(host) else {
      return nil
    }

    guard let keyIdentifier = host.key, let privateKey = privateKey(forIdentifier: keyIdentifier) else {
      return nil
    }

    return privateKey
  }
  
  public func defaultKeys() -> [(String, String)] {
    let publicKeys = BKPubKey.all()
    
    let defaultKeyNames = ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"]
    return publicKeys
      .filter {
        defaultKeyNames.contains($0.id)
      }
      .map {
        ($0.loadPrivateKey(), $0.id)
      }
      .compactMap {
        guard
          let privateKey = $0.0
        else {
          return nil
        }
        return (privateKey, $0.1)
      }
  }
  
  public func password(forHost host: String) -> String? {
    _host(host)?.password
  }

  public func hostName(forHost host: String) -> String? {
    _host(host)?.hostName
  }
  
  public func proxyCommand(forHost host: String) -> String? {
    _host(host)?.proxyCmd
  }
  
  public func user(forHost host: String) -> String? {
    let user = _host(host)?.user ?? ""
    return user.isEmpty ? nil : user
  }
  
  public func port(forHost host: String) -> String? {
    if let port = _host(host)?.port {
      return port.stringValue
    } else {
      return nil
    }
  }
}
