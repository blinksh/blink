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


public typealias Argv = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?

extension Argv {
  static func build(_ args: [String]) -> (argc: Int32, argv: Self, buff: UnsafeMutablePointer<Int8>?) {
    let argc = args.count

    let cArgsSize = args.reduce(argc) { $0 + $1.utf8.count }

    // Store arguments in contiguous memory.
    guard
      let argsBuffer = calloc(cArgsSize, MemoryLayout<Int8>.size)?.assumingMemoryBound(to: Int8.self)
    else {
      return (argc: 0, argv: nil, buff: nil)
    }

    let argv = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: argc)

    var currentArgsPosition = argsBuffer

    args.enumerated().forEach { i, arg in
      let len = strlen(arg)
      strncpy(currentArgsPosition, arg, len)
      argv[i] = currentArgsPosition
      currentArgsPosition = currentArgsPosition.advanced(by: len + 1)
    }


    return (argc: Int32(argc), argv: argv, buff: argsBuffer)
  }

  static func build(_ args: String ...) -> (argc: Int32, argv: Self, buff: UnsafeMutablePointer<Int8>?) {
    build(args)
  }

  func args(count: Int32) -> [String] {
    guard let argv = self else {
      return []
    }
    var res: [String] = []
    for i in 0..<count {
      guard let cStr = argv[Int(i)] else {
        res.append("")
        continue
      }

      res.append(String(cString: cStr))
    }
    return res
  }
}

struct CommandError: Error {
  let message: String
}

func tty() -> TermDevice {
  let session = Unmanaged<MCPSession>.fromOpaque(thread_context).takeUnretainedValue()
  return session.device
}
