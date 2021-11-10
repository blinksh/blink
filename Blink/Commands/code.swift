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
import NonStdIO
import ArgumentParser
import BlinkCode
import Network

class SharedFP {
  let service: CodeFileSystemService

  init(port: UInt16) {
    let p = NWEndpoint.Port(rawValue: port)!
    service = try! CodeFileSystemService.init(listenOn: p, tls: true, finished: { error in
      if let error = error {
        print("Listener failed - \(error)")
      }
    })
  }

  static var shared: SharedFP? = nil

  static func startedFP(port: UInt16 = 50000) -> SharedFP {
    guard let shared = shared,
          shared.service.state == .ready else {
      // We may need the WebServer to restart, instead of creating a new object.
      // My theory is that this stops, and I don't get the new state because we are in background.
      let shared = SharedFP(port: port)
      self.shared = shared
      return shared
    }

    return shared
  }
}

struct CodeCommand: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "code",
    abstract: "Starts code editor"
  )

  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart

  @Argument(
    help: "Path to connect to",
    transform: { try FileLocationPath($0) }
  )
  var path: FileLocationPath?

  @Option(
    help: "URL for vscode"
  )
  var vscode: String = "https://vscode.dev"
  
  mutating func run() throws {
    try Code().start(self)
  }
}

class Code {
  func start(_ cmd: CodeCommand) throws {
    let fp = SharedFP.startedFP(port: 50000)
    let port = fp.service.port
    
    var path: FileLocationPath
    // Build a rootPath
    if cmd.path == nil {
      path = try FileLocationPath(".")
    } else {
      path = cmd.path!
    }

    guard let rootURI = path.codeFileSystemURI else {
      throw CommandError(message: "Could not parse path.")
    }

    let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
    let token = fp.service.registerMount(name: "xxx", root: rootURI.absoluteString)
    
    NotificationCenter.default.addObserver(forName: .deviceTerminated, object: nil, queue: nil) { notification in
      guard let device = notification.userInfo?["device"] as? TermDevice else {
        return
      }
      if session.device == device {
        fp.service.deregisterMount(token)
      }
      NotificationCenter.default.removeObserver(self)
    }

    DispatchQueue.main.async {
      let url = URL(string: cmd.vscode)!
////      var url = URL(string: "https://github.com/codespaces")!
//
      let agent = "BlinkSH/15 (wss;\(port);\(token))"
      session.device.view.addBrowserWebView(url, agent: agent)
    }
  }
}

@_cdecl("code_main")
public func code_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin,  nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let io = NonStdIO.standart
  io.out = OutputStream(file: thread_stdout)
  io.err = OutputStream(file: thread_stderr)

  return CodeCommand.main(Array(argv.args(count: argc)[1...]), io: io)
}

extension FileLocationPath {
  // blinkfs:/path
  // blinksftp://user@host:port/path
  fileprivate var codeFileSystemURI: URL? {
    if proto == .local {
      return URL(string: uriProtocolIdentifier +
                 filePath.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
    } else {
      // "/user@host#port" -> "/user@host:port"
      guard let hostPath = hostPath else {
        return nil
      }
      let host = "/\(hostPath.replacingOccurrences(of: "#", with: ":"))"
      return URL(string: uriProtocolIdentifier + host)?.appendingPathComponent(filePath)
    }
  }

  fileprivate var uriProtocolIdentifier: String {
    switch proto {
    case .local:
      return "blinkfs:"
    default:
      return "blinksftp:/"
    }
  }
}
