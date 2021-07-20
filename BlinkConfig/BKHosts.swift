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
import SSHConfig


extension BKHosts {
  
  @objc public static func saveAllToSSHConfig() {
    do {
      let config = SSHConfig()
      let hosts = BKHosts.allHosts() ?? []
      for h in hosts {
        var cfg: [(String, Any)] = []
        if let user = h.user, !user.isEmpty {
          cfg.append(("User", user))
        }
        if let port = h.port {
          cfg.append(("Port", port.intValue))
        }
        if let hostName = h.hostName, !hostName.isEmpty {
          cfg.append(("HostName", hostName))
        }
        if let key = h.key, !key.isEmpty, key != "None" {
          cfg.append(("IdentityFile", key))
        }
        if let proxyCmd = h.proxyCmd, !proxyCmd.isEmpty {
          cfg.append(("ProxyCommand", proxyCmd))
        }
        
        try config.add(alias: h.host, cfg: cfg)
      }
      
      guard
        let data = config.string().data(using: .utf8),
        let url = BlinkPaths.blinkSSHConfigFileURL()
      else {
        print("can't convert to data")
        return
      }
      
      try data.write(to: url)
      
    } catch {
      print(error)
    }
  }
}
