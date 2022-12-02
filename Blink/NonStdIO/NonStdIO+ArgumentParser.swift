//
//  File.swift
//  
//
//  Created by Yury Korolev on 21.05.2021.
//


//#if canImport(ArgumentParser)

import Foundation
import ArgumentParser

public struct VerboseOptions: ParsableArguments {
  @Flag(name: .long)
  public var verbose: Bool = false
  
  @Flag(name: .long)
  public var quiet: Bool = false
  
  public init() { }
}


public protocol NonStdIOCommand: ParsableCommand, WithNonStdIO {
  var io: NonStdIO { get }
  var verboseOptions: VerboseOptions { get set }
}

public extension ParsableCommand where Self: WithNonStdIO {
  static func main(_ args: [String]? = nil, io: NonStdIO = .init()) -> Int32 {
    do {
      var command = try parseAsRoot(args)
      
      if let cmd = command as? WithNonStdIO {
        cmd.io.in_ = io.in_
        cmd.io.err = io.err
        cmd.io.out = io.out
      }
      
      if let cmd = command as? NonStdIOCommand {
        cmd.io.verbose = cmd.verboseOptions.verbose
        cmd.io.quiet = cmd.verboseOptions.quiet
        
        command = cmd
      }
      
      try command.run()
    } catch {
      return terminalIOExit(withError: error, io: io)
    }
    
    return 0
  }
  
  static func terminalIOExit(withError error: Error? = nil, io: NonStdIO) -> Int32 {
    guard let error = error else {
      return 0
    }
    
    var txt = io.quiet ? message(for: error) : fullMessage(for: error)
    let exitCode = exitCode(for: error).rawValue
    if txt.isEmpty {
      return exitCode
    }
    
    if !io.quiet,
      let localizedError = error as? LocalizedError,
      let recoverySuggestion = localizedError.recoverySuggestion,
      !recoverySuggestion.isEmpty {
      
      txt += "\n" + recoverySuggestion
    }
    
    if exitCode == 0 {
      io.print(txt)
    } else {
      io.printError(txt)
    }
    return exitCode
  }
}


//#endif
