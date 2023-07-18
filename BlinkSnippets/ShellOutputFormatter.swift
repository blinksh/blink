//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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


public enum ShellOutputFormatter {
  case block,
       lineBySemicolon,
       beginEnd

  public func format(_ script: String) -> String {
    let commands = parseCommands(script)

    // Escape if no multi-line
    if commands.isEmpty {
      return ""
    } else if commands.count == 1 {
      return commands[0]
    }
    
    switch self {
    case .lineBySemicolon:
      return commands.joined(separator: "; ")
    case .block:
      return script.wrapIn(prefix: "$(\n", suffix: "\n)")
    case .beginEnd:
      return script.wrapIn(prefix: "begin\n", suffix: "\nend")
    }
  }
  
  private func parseCommands(_ script: String) -> [String] {
    // Receives text and splits into multiple commands
    var currentCommand = ""
    var commands: [String] = []
    
    for line in script
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .newlines) {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)

      if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
        continue
      }

      if trimmedLine.hasSuffix("\\") {
        currentCommand += line.appending("\n")
      } else {
        currentCommand += line
        commands.append(currentCommand)
        currentCommand = ""
      }
    }
    
    return commands
  }
}

extension String {
  func wrapIn(prefix: String, suffix: String) -> String {
    return "\(prefix)\(self)\(suffix)"
  }
}
