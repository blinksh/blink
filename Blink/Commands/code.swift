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
    service = try! CodeFileSystemService.init(listenOn: p, tls: true)
  }
  
  static var shared: SharedFP? = nil
  
  static func startedFP(port: UInt16 = 50000) -> SharedFP {
    if shared == nil {
      shared = SharedFP(port: port)
    }
    
    return shared!
  }
}

struct Code: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "code",
    abstract: "Starts code editor"
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
 
  @Argument(
    help: .init(
      "If a <command> is specified, it is executed on the container instead of a login shell",
      valueName: "path"
    )
  )
  var path: String?
  
  func run() throws {
    var pwd = FileManager.default.currentDirectoryPath
    if let path = path {
      var p = URL(fileURLWithPath: pwd)
      p.appendPathComponent(path)
      pwd = p.absoluteURL.path
    }
    pwd = (pwd as NSString).standardizingPath
    print(pwd)
    
    let fp = SharedFP.startedFP(port: 50000)
    let port = fp.service.port
    let token = fp.service.registerMount(name: "Test", root: "blink-fs:" + pwd)
    let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
    DispatchQueue.main.async {
      let url = URL(string: "https://vscode.dev")!
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
  
  return Code.main(Array(argv.args(count: argc)[1...]), io: io)
}
