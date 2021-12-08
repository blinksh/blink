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

import SSH


public struct BKSSHHost {
  private let content: [String:Any]

  public var hostName: String?
  public var identityFile: [String]?
  public var password: String?
  public var user: String?
  public var port: String?
  public var proxyCommand: String?
  public var proxyJump: String?
  public var compression: Bool?
  public var compressionLevel: Int?
  public var connectionTimeout: Int?
  public var logLevel: SSHLogLevel?
  public var controlMaster: ControlMasterOption?
  public var forwardAgent: Bool?
  public var sendEnv: [String]?
  public var strictHostKeyChecking: Bool?
  // TODO SendEnv, Tunnels, etc...
  
  public struct ValidationError: Error {
    let message: String
    public var description: String { message }
  }
  
  public init(content: [String: Any]) throws {
    self.content = content
    
    func castValue<T: SSHValue>(_ value: Any) throws -> T {
      // Values must be mapped to a String
      let value = value as! String
      return try T(castSSHValue: value)
    }
    
    func castList<T: SSHValue>(_ value: Any) throws -> [T] {
      if let list = value as? [String] {
        return try list.map { try T(castSSHValue: $0) }
      } else {
        return try (value as! String)
          .split(separator: " ")
          .map { try T(castSSHValue: String($0)) }
      }
    }
    
    for (key, value) in content {
      do {
        let key = key.lowercased()
        
        switch key {
        case "hostname":                self.hostName               = try castValue(value)
        case "password":                self.password               = try castValue(value)
        case "user":                    self.user                   = try castValue(value)
        case "port":                    self.port                   = try castValue(value)
        case "proxycommand":            self.proxyCommand           = try castValue(value)
        case "proxyjump":               self.proxyJump              = try castValue(value)
        case "compression":             self.compression            = try castValue(value)
        case "compressionlevel":        self.compressionLevel       = try castValue(value)
        case "connectiontimeout":       self.connectionTimeout      = try castValue(value)
        case "loglevel":                self.logLevel               = try castValue(value)
        case "controlmaster":           self.controlMaster          = try castValue(value)
        case "forwardagent":            self.forwardAgent           = try castValue(value)
        case "stricthostkeychecking":   self.strictHostKeyChecking  = try castValue(value)
        case "sendenv":                 self.sendEnv                = try castList(value)
        case "identityfile":            self.identityFile           = try castList(value)
        default:
          // Skip unknown
          break
        }
      } catch let error as ValidationError {
        throw ValidationError(message: "\(key) \(value) - \(error.message)")
      }
    }
  }

  public func merge(_ host: BKSSHHost) throws -> BKSSHHost {
    var configDict = content
    configDict.mergeWithSSHConfigRules(host.content)
    return try BKSSHHost(content: configDict)
  }

  public func sshClientConfig(authMethods: [SSH.AuthMethod]?,
                              verifyHostCallback: SSHClientConfig.RequestVerifyHostCallback? = nil,
                              agent: SSHAgent? = nil,
                              logger: SSHLogPublisher? = nil) -> SSHClientConfig {
    SSHClientConfig(
      user: user ?? "root",
      port: port,
      proxyJump: proxyJump,
      proxyCommand: proxyCommand,
      authMethods: authMethods,
      agent: agent,
      loggingVerbosity: logLevel,
      verifyHostCallback: verifyHostCallback,
      connectionTimeout: connectionTimeout,
      sshDirectory: BlinkPaths.ssh()!,
      logger: logger,
      compression: compression,
      compressionLevel: compressionLevel
    )
  }
}

fileprivate protocol SSHValue {
  init(castSSHValue val: String) throws
}

extension Bool: SSHValue {
  fileprivate init(castSSHValue val: String) throws {
    switch val.lowercased() {
    case "yes":
      self.init(true)
    case "no":
      self.init(false)
    default:
      throw BKSSHHost.ValidationError(message: "Value must be yes/no")
    }
  }
}

extension Int: SSHValue {
  fileprivate init(castSSHValue val: String) throws {
    guard let _ = Int(val) else {
      throw BKSSHHost.ValidationError(message: "Value must be a number")
    }
    self.init(val)!
  }
}

extension String: SSHValue {
  fileprivate init(castSSHValue val: String) throws {
    self.init(val)
  }
}

extension SSHLogLevel: SSHValue {
  fileprivate init(castSSHValue val: String) throws {
    guard let _ = SSHLogLevel(val) else {
      throw BKSSHHost.ValidationError(message: "Value must be QUIET, etc...")
    }
    self.init(val)!
  }
}

public enum ControlMasterOption: String, SSHValue {
  case auto     = "auto"
  case ask      = "ask"
  case autoask  = "autoask"
  case yes      = "yes"
  case no       = "no"
  
  fileprivate init(castSSHValue val: String) throws {
    guard let _ = ControlMasterOption(rawValue: val) else {
      throw BKSSHHost.ValidationError(message: "Value must be auto, ask, autoask, yes or no")
    }
    self.init(rawValue: val)!
  }
}
