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
import SSHConfig


// Responsible to intermediate between the Blink Configuration formats and the
// SSHClient requirements, facilitating information between them.
// TODO This will work a lot better as a singleton.
public struct BKConfig {
  let defaultKeyNames = ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"]

  private let _allHosts: [BKHosts]
  private let _allIdentities: [BKPubKey]
  private let bkSSHConfig: SSHConfig

  // TODO Config files
  public init() throws {
    _allHosts = BKHosts.allHosts()
    _allIdentities = BKPubKey.all()
    bkSSHConfig = try SSHConfig.parse(url: BlinkPaths.blinkGlobalSSHConfigFileURL())
  }

  private func _host(_ host: String) -> BKHosts? {
    return _allHosts.first(where: { $0.host == host })
  }

  // Return the stored configuration given the host.
  // The root for the configuration is now the file sequence from .blink/ssh_config.
  public func bkSSHHost(_ alias: String) throws -> BKSSHHost {
    var sshConfig = try bkSSHConfig.resolve(alias: alias)

    // Add protected data (password)
    if let password = _host(alias)?.password {
      sshConfig["password"] = password
    }

    return try BKSSHHost(content: sshConfig)
  }
  
  public func bkSSHHost(_ alias: String, extending baseHost: BKSSHHost) throws -> BKSSHHost {
    let sshConfigHost = try self.bkSSHHost(alias)
    
    return try baseHost.merge(sshConfigHost)
  }

  public func privateKey(forIdentifier identifier: String) -> (String, String)? {
    guard
      let privateKey = _allIdentities.first(where: { $0.id == identifier })?.loadPrivateKey()
    else {
      return nil
    }
    
    return (privateKey, identifier)
  }

  public func signer(forIdentity identity: String) -> (Signer, String)? {
    guard
      let signer = _allIdentities.signerWithID(identity)
    else {
      return nil
    }
    
    return (signer, identity)
  }
  
  public func signer(forHost host: BKSSHHost) -> [(Signer, String)]? {
    guard
      let identity = host.identityFile
    else {
      return nil
    }
    
    return identity.compactMap { signer(forIdentity: $0) }
  }

  public func defaultSigners() -> [(Signer, String)] {
    return defaultKeyNames.compactMap {
      signer(forIdentity: $0)
    }
  }
  
  public func defaultKeys() -> [(String, String)] {
    return _allIdentities
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
}
