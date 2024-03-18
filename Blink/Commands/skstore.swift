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
import StoreKit
import ArgumentParser
import BlinkConfig

import ios_system

struct SKStoreCmd: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "skstore",
    abstract: "SKStorage",
    shouldDisplay: false
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standard

  @Argument(
    help: "attribute"
  )
  var attribute: String
  var infoURL: URL { BlinkPaths.blinkURL().appendingPathComponent(".receiptInfo") }
  
  func run() throws {
    let sema = DispatchSemaphore(value: 0)
    
    if attribute != "blink-rules" {
      return
    }
    
    let sk = SKStore()
    var error: Error? = nil

    let c = sk.fetchReceiptURLPublisher()
      .tryMap { url in 
        let d = try Data(contentsOf: url, options: .alwaysMapped)
        let str = d.base64EncodedString(options: [])
        try str.write(to: infoURL, atomically: false, encoding: .utf8)
      }
      .sink(receiveCompletion: { completion in
        if case .failure(let err) = completion {
          error = err
        }
        sema.signal()
      }, receiveValue: { _ in })

    sema.wait()
    
    if let error = error {
      throw error
    }
  }
}


@_cdecl("skstore_main")
public func skstore_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let io = NonStdIO.standard
  io.out = OutputStream(file: thread_stdout)
  io.err = OutputStream(file: thread_stderr)
  
  return SKStoreCmd.main(Array(argv.args(count: argc)[1...]), io: io)
}
