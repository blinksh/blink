//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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


extension SSHClient {
  /**
   Deletes entry for `host` on the given `.ssh` `inPath` where the `known_hosts` file is stored.
   
   - Parameters:
   - inPath: `String` specifiying the path where the `.ssh` folder is located
   - host: hostname to delete from the `.ssh/known_hosts`
   */
  public static func deleteKnownHost(inPath: String, host: String) throws {
    let knownHostsPath = inPath + "/known_hosts"
    
    guard let data = try? String(contentsOfFile: knownHostsPath, encoding: String.Encoding.utf8) else {
      throw DeleteKnownHostsError.failedReadingKnownHostsFile(path: knownHostsPath)
    }
    
    let myStrings = data.components(separatedBy: CharacterSet.newlines)
    
    /// Only match the host line if it's the first word in the line and it's followed by a space
    let filtered = myStrings.filter { $0.matchingStrings(regex: "^(\(host))\\s").flatMap({ $0 }).count == 0 } //.starts(with: host) }
    
    let joined = filtered.filter({ $0.count > 0 }).joined(separator: "\n") + "\n"
    
    do {
      try joined.write(toFile: knownHostsPath, atomically: false, encoding: .utf8)
    } catch {
      throw DeleteKnownHostsError.failedWritingKnownHostsFile(path: knownHostsPath)
    }
  }
}

public enum DeleteKnownHostsError: Error {
  case didNotFindHost
  case failedWritingKnownHostsFile(path: String)
  case failedReadingKnownHostsFile(path: String)
  
  public var description: String {
    switch  self {
    case .didNotFindHost:
      return "Did not find host"
    case .failedWritingKnownHostsFile(let path):
      return "Failed to write to known_hosts file at path \(path)"
    case .failedReadingKnownHostsFile(let path):
      return "Failed to read from known_hosts file at path \(path)"
    }
  }
}
