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
    help: "Path to connect to",
    transform: { try FileLocationPath($0) }
  )
  var path: FileLocationPath?
  
  mutating func run() throws {
    // You usually start at the ~, with that format.
    // Problem is we need to pass that as a path to code, but we do not know
    // what the canonical route will be.
    // TODO Idea is to resolve and build the path here.
    // The connections then will start from here, instead of from the CodeFileSystem.
    // But that one will have to restart a connection if it is lost anyway.

    
//    let fm = FileManager.default
//    var pwd = fm.currentDirectoryPath
//    if let path = path {
//      var p = URL(fileURLWithPath: pwd)
//      p.appendPathComponent(path)
//      pwd = p.absoluteURL.path
//    }
//
//
//    pwd = (pwd as NSString).standardizingPath
//
    var openFile: String? = nil
    var newFile: String? = nil
//    var isDir: ObjCBool = false
//
//    if fm.fileExists(atPath: pwd, isDirectory: &isDir) {
//      if isDir.boolValue {
//
//      } else {
//        openFile = "blinkfs:" + pwd
//        pwd = (pwd as NSString).deletingLastPathComponent
//      }
//    } else {
//      newFile = "blinkfs:" + pwd
//      pwd = (pwd as NSString).deletingLastPathComponent
//    }
    
//    print(pwd)
    
    let fp = SharedFP.startedFP(port: 50000)
    let port = fp.service.port

    // TODO Maybe resolve if not absolute
    // Build a rootPath
    if path == nil {
      path = try FileLocationPath(".")
    }
    
    guard let rootURI = path!.codeFileSystemURI else {
      throw CommandError(message: "Could not parse path.")
    }
    let token = fp.service.registerMount(name: "Test", root: rootURI.absoluteString, newFile: newFile, openFile: openFile)
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

extension FileLocationPath {
  // blinkfs:/path
  // blinksftp://user@host:port/path
  fileprivate var codeFileSystemURI: URL? {
    if proto == .local {
      return URL(string: uriProtocolIdentifier + filePath)
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
