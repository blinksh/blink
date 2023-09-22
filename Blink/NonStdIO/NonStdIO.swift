//
//  File.swift
//
//
//  Created by Yury Korolev on 20.05.2021.
//

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
  
  static var stdout: OutputStream { .init(file: Darwin.stdout) }
  static var stderr: OutputStream { .init(file: Darwin.stderr) }
}


public class NonStdIO: Codable {
  public var in_: InputStream
  public var out: OutputStream
  public var err: OutputStream
  
  public var verbose: Bool = false
  public var quiet: Bool = false
  
  public init() {
    self.in_ = InputStream.stdin
    self.out = OutputStream.stdout
    self.err = OutputStream.stderr
  }
  
  public required init(from decoder: Decoder) throws {
    self.in_ = InputStream.stdin
    self.out = OutputStream.stdout
    self.err = OutputStream.stderr
  }
  
  public func encode(to encoder: Encoder) throws {
  }
  
  public static let standart = NonStdIO()
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


