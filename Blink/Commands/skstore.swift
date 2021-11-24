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
import NonStdIO


struct SKStoreCmd: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "skstore",
    abstract: "SKStorage",
    shouldDisplay: false
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart

  @Argument(
    help: "attribute"
  )
  var attribute: String
  
  func run() throws {
    let sema = DispatchSemaphore(value: 0)
    
    if attribute != "" {
      return
    }
    
    let sk = SKStore()
    sk.start { message in
      if let message = message {
        print(message)
      }
      sema.signal()
    }
    sema.wait()
  }
}

@objc class SKStore: NSObject {
  var infoURL: URL { BlinkPaths.blinkURL().appendingPathComponent(".receiptInfo") }
  var done: ((String?) -> Void)!
  var skReq: SKReceiptRefreshRequest? = nil
  
  @objc func start(done: @escaping ((String?) -> Void)) {
    self.done = done
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
      return done("No URL for receipt found.")
    }
    if !FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
      let skReq = SKReceiptRefreshRequest(receiptProperties: nil)
      skReq.delegate = self
      skReq.start()
      self.skReq = skReq
      return
    }
    
    store(appStoreReceiptURL)
  }
  
  func store(_ url: URL) {
    do {
      let d = try Data(contentsOf: url, options: .alwaysMapped)
      let str = d.base64EncodedString(options: [])
      try str.write(to: infoURL, atomically: false, encoding: .utf8)
      done(nil)
    } catch {
      done(error.localizedDescription)
    }
  }
}

extension SKStore: SKRequestDelegate {
  func requestDidFinish(_ request: SKRequest) {
    if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
       FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
      store(appStoreReceiptURL)
    } else {
      done("No receipt found after request.")
    }
  }
  func request(_ request: SKRequest, didFailWithError error: Error) {
    done(error.localizedDescription)
  }
}

@_cdecl("skstore_main")
public func skstore_main(argc: Int32, argv: Argv) -> Int32 {
  setvbuf(thread_stdin, nil, _IONBF, 0)
  setvbuf(thread_stdout, nil, _IONBF, 0)
  setvbuf(thread_stderr, nil, _IONBF, 0)

  let io = NonStdIO.standart
  io.out = OutputStream(file: thread_stdout)
  io.err = OutputStream(file: thread_stderr)
  
  return SKStoreCmd.main(Array(argv.args(count: argc)[1...]), io: io)
}
