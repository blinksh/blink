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

public struct InputStream {
  let fd: Int32
  let file: UnsafeMutablePointer<FILE>
  
  public init(file: UnsafeMutablePointer<FILE>) {
    self.file = file
    self.fd = fileno(file)
  }
  
  
  public func readLine() -> String? {
    var char: UInt8 = 0
    let newLineChar: UInt8 = 0x0a
    var data = Data()
    while Darwin.read(fd, &char, 1) == 1 {
      if char == newLineChar {
        break
      }
      data.append(char)
    }
    
    return String(data: data, encoding: .utf8)
  }
  
  static var stdin:  InputStream  { .init(file: Darwin.stdin) }
  
}

public struct OutputStream: TextOutputStream {
  let fd: Int32
  let file: UnsafeMutablePointer<FILE>
  
  public init(file: UnsafeMutablePointer<FILE>) {
    self.file = file
    self.fd = fileno(file)
  }
  
  public func write(_ string: String) {
    Darwin.write(fd, string, string.utf8.count)
  }
  
  public func flush() {
    Darwin.fflush(file)
  }

  // Disable mouse reporting a remote program may have left on, e.g. on a dropped connection.
  // hterm keeps a single report mode, so 1003l disables 1000/1002/1003 alike.
  public func resetMouseModes() {
    write("\u{1b}[?1003l\u{1b}[?1006l")
  }

  // Raw sessions handle CR themselves; cooked output relies on the terminal adding it.
  public func setAutoCR(_ autoCR: Bool) {
    write("\u{1b}]1337;BlinkAutoCR=\(autoCR ? 1 : 0)\u{07}")
  }
  
  static var stdout: OutputStream { .init(file: Darwin.stdout) }
  static var stderr: OutputStream { .init(file: Darwin.stderr) }
}


public class NonStdIO: Codable {
  public var in_: InputStream
  public var out: OutputStream
  public var err: OutputStream
  
  public var verbose: Bool = false
  public var quiet: Bool = false
  
  public init(in_: InputStream? = nil, out: OutputStream? = nil, err: OutputStream? = nil) {
    self.in_ = in_ ?? InputStream.stdin
    self.out = out ?? OutputStream.stdout
    self.err = err ?? OutputStream.stderr
  }
  
  public required init(from decoder: Decoder) throws {
    self.in_ = InputStream.stdin
    self.out = OutputStream.stdout
    self.err = OutputStream.stderr
  }
  
  public func encode(to encoder: Encoder) throws {
  }
  
  public static let standard = NonStdIO()
}

public protocol WithNonStdIO {
  var io: NonStdIO { get }
}

public extension NonStdIO {
  func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    guard !quiet else {
      return
    }
    let s = items.map(String.init(describing:)).joined(separator: separator)
    Swift.print(s, terminator: terminator, to: &out)
  }
  
  func printError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    Swift.print(s, terminator: terminator, to: &err)
  }
  
  func printDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    guard verbose else {
      return
    }
    let s = items.map(String.init(describing:)).joined(separator: separator)
    Swift.print(s, terminator: terminator, to: &out)
  }
}


public extension WithNonStdIO {
  func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    io.print(s, terminator: terminator)
  }
  
  func printError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    io.printError(s, terminator: terminator)
  }
  
  func printDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    io.printDebug(s, terminator: terminator)
  }
}


