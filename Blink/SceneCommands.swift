//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2025 Blink Mobile Shell Project
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


protocol SceneCommand {
  func perform(on spaceController: SpaceController)
}


enum SceneCommands {
  static func from(url: URL) -> SceneCommand? {
    OpenSSHCommand(url: url)
      ?? OpenCodeCommand(url: url)
      ?? OpenHTTPCommand(url: url)
  }
}


struct OpenSSHCommand: SceneCommand {
  let sshCommand: String

  init?(url: URL) {
    // Goal is to tokenize a SSH Command. The risk is that the URL may contain
    // injection parameters. We sanitize the input and make sure the result —
    // specially the user@host part — is a valid shell token. The SSH library
    // takes care of validating the host, user, etc.
    guard url.scheme == "ssh" else { return nil }
    guard let host = url.host?.removingPercentEncoding,
          host.rangeOfCharacter(from: .controlCharacters) == nil,
          host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          !host.starts(with: "-"),
          !host.starts(with: ".") else {
      return nil
    }

    var command = "ssh "

    if let port = url.port {
      command += "-p \(port) "
    }

    if let userinfo = url.user?.removingPercentEncoding,
       userinfo.rangeOfCharacter(from: .controlCharacters) == nil {
      // Extract only the username before the first ";" if conn-params exist.
      let username = userinfo.components(separatedBy: ";").first ?? ""
      guard username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            !username.starts(with: "-"),
            !username.starts(with: ".") else {
        return nil
      }

      if username.count > 0 {
        command += "-l \(username) "
      }
    }

    command += "\(host)"

    guard command.rangeOfCharacter(from: .controlCharacters) == nil else {
      return nil
    }

    self.sshCommand = command
  }

  func perform(on spaceController: SpaceController) {
    spaceController.runShellSessionIntent(command: sshCommand)
  }
}


// vscode://<path_to_file>
// vscode://<repository>
// vscode://github.codespaces/connect?name=
// vscode://file/path/to/file/file.ext:55:20
struct OpenCodeCommand: SceneCommand {
  let codeCommand: String

  init?(url: URL) {
    guard url.scheme == "vscode" else { return nil }
    guard let fileProtocol = url.host else { return nil }

    var command = "code "
    var urlPath = url.path
    if ["sftp", "local"].contains(fileProtocol) {
      if fileProtocol == "sftp" {
        // host/ -> host:/;  host/~ -> host:~/
        let components = url.pathComponents
        if components.count < 2 {
          return nil
        }
        let hostName = components[1]
        command += "\(hostName):"
        urlPath = url.pathComponents[2...].joined(separator: "/")
        if urlPath.isEmpty {
          urlPath = "/"
        }
      }
      command += "\(urlPath)"
    } else if fileProtocol.lowercased() == "github.codespaces",
              url.path == "/connect",
              let codespaceName = url.getQueryStringParameter(param: "name") {
      command += "https://\(codespaceName).github.dev"
    } else {
      command += url.absoluteString
    }

    guard command.rangeOfCharacter(from: .controlCharacters) == nil else {
      return nil
    }

    self.codeCommand = command
  }

  func perform(on spaceController: SpaceController) {
    spaceController.runShellSessionIntent(command: codeCommand)
  }
}


fileprivate extension URL {
  func getQueryStringParameter(param: String) -> String? {
    guard let url = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
    return url.percentEncodedQueryItems?.first(where: { $0.name == param })?.value
  }
}


struct OpenHTTPCommand: SceneCommand {
  let codeCommand: String

  init?(url: URL) {
    guard url.scheme == "http" || url.scheme == "https" else { return nil }
    let urlCommand = url.absoluteString
    guard urlCommand.rangeOfCharacter(from: .controlCharacters) == nil else {
      return nil
    }
    self.codeCommand = "code \(urlCommand)"
  }

  func perform(on spaceController: SpaceController) {
    spaceController.runShellSessionIntent(command: codeCommand)
  }
}
