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


public class BKGlobalSSHConfig: NSObject, NSSecureCoding {
  let user: String

  public static var supportsSecureCoding: Bool = true
 
  @objc public init(user: String) {
    self.user = user
    
    super.init()
  }

  public required init?(coder decoder: NSCoder) {
    guard let user = decoder.decodeObject(of: [NSString.self], forKey: "user") as? String
    else {
      return nil
    }

    self.user = user
  }

  public func encode(with coder: NSCoder) {
    coder.encode(user, forKey: "user")
  }

  // @objc public func save() {
  //   do {
  //     let data = try NSKeyedArchiver.archivedData(
  //       withRootObject: self,
  //       requiringSecureCoding: true
  //     )

  //     try data.write(to: BlinkPaths.globalSSHConfig,
  //                    options: NSDataWritingAtomic | NSDataWritingFileProtectionNone)
  //   } catch {
  //     print(error)
  //   }
  // }

  // public static func load() -> BKGlobalSSHConfig? {
  //   do {
  //     let data = try Data(contentsOf: BlinkPaths.globalSSHConfig)

  //     return try NSKeyedUnarchiver.decodeObject(data) as? BKGlobalSSHConfig
  //   } catch {
  //     print(error)
  //     return nil
  //   }
  // }

  @objc public func saveFile() {
    do {
      let config = SSHConfig()

      // TODO High level migration mechanism.
      try config.add(alias: "*", cfg: [("User", self.user), 
                                       ("ControlMaster", "auto"),
                                       ("SendEnv", "LANG")])
   
      // Config does not currently allow for single lines
      let configString = """
Include ssh_config
Include ../.ssh/config

\(config.string())
"""
      guard let data = configString.data(using: .utf8),
            let url = BlinkPaths.blinkGlobalSSHConfigFileURL()
      else {
        print("Could not write global ssh configuration")
        return
      }

      try data.write(to: url)
    } catch(let error) {
      // TODO We could/should rely on a Log + Alert mechanism.
      print(error.localizedDescription)
    }
  }
}
