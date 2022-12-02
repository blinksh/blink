////
////  File.swift
////  
////
////  Created by Yury Korolev on 31.05.2021.
////
//
//
////#if canImport(Spinner)
//
//import Spinner
//
//public struct NonStdIOSpinnerUI: SpinnerUI {
//  private let _io: NonStdIO
//  
//  public init(io: NonStdIO) {
//    _io = io
//  }
//  
//  public func display(string: String) {
//    _io.out.write("\r" + string)
//  }
//  
//  public func hideCursor() {
//    _io.out.write("\u{001B}[?25l")
//  }
//  
//  public func unhideCursor() {
//    _io.out.write("\u{001B}[?25h")
//  }
//  
//  public func printString(_ str: String) {
//    _io.print(str, terminator: "")
//  }
//}
//
////#endif
