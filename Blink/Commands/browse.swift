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
import ArgumentParser
import BlinkCode
import Network


struct BrowseCommand: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "browser",
    abstract: "Opens web page",
    discussion: discussion
  )
  static let discussion = """
    
    """

  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart

  @Argument(
    help: "Path to connect to or http(s) vscode like editor url",
    transform: {
      guard let url = URL(string: $0) else {
        throw ArgumentParser.ValidationError("Invalid vscode url")
      }
      return url
    }

  )
  var url: URL?

  mutating func run() throws {
    let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
    
    let url = url ?? URL(string: "https://google.com")!
    DispatchQueue.main.async {
      session.device?.view?.addBrowserWebView(url, agent: "", injectUIO: false)
    }
  }
}


@_cdecl("browse_main")
public func browse_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin,  nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let io = NonStdIO.standart
  io.in_ = InputStream(file: thread_stdin)
  io.out = OutputStream(file: thread_stdout)
  io.err = OutputStream(file: thread_stderr)
  
  return BrowseCommand.main(Array(argv.args(count: argc)[1...]), io: io)
}
