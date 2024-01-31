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

  public var bindAddress: String?
  public var ciphers: String?
  public var compression: Bool?
  public var compressionLevel: Int?
  //public var connectionAttempts: Int?
  public var connectionTimeout: Int?
  public var controlMaster: ControlMasterOption?
  public var dynamicForward: [OptionalBindAddressInfo]?
  public var exitOnForwardFailure: Bool?
  public var forwardAgent: Bool?
  public var gatewayPorts: Bool?
  //public var hostKeyAlias: String?
  public var hostbasedAuthentication: Bool?
  public var hostKeyAlgorithms: String?
  public var hostName: String?
  public var identityFile: [String]?
  //public var identitiesOnly: Bool?
  public var kbdInteractiveAuthentication: Bool?
  public var kexAlgorithms: String?
  public var localForward: [PortForwardInfo]?
  public var logLevel: SSHLogLevel?
  public var macs: String?
  public var password: String?
  //public var numberOfPasswordPrompts: Int?
  public var passwordAuthentication: Bool?
  public var port: String?
  //public var preferredAuthentications: String?
  public var proxyCommand: String?
  public var proxyJump: String?
  public var pubKeyAuthentication: Bool?
  public var rekeyLimit: BytesNumber?
  public var remoteCommand: String?
  public var remoteForward: [PortForwardInfo]?
  public var requestTty: TTYBool?
  public var sendEnv: [String]?
  public var strictHostKeyChecking: Bool?
  public var user: String?

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
        case "bindaddress":                   self.bindAddress                  = try castValue(value)
        case "ciphers":                       self.ciphers                      = try castValue(value)
        case "compression":                   self.compression                  = try castValue(value)
        case "compressionlevel":              self.compressionLevel             = try castValue(value)
        case "connectiontimeout":             self.connectionTimeout            = try castValue(value)
        case "controlmaster":                 self.controlMaster                = try castValue(value)
        case "dynamicforward":                self.dynamicForward               = try castList(value)
        case "exitonforwardfailure":          self.exitOnForwardFailure         = try castValue(value)
        case "forwardagent":                  self.forwardAgent                 = try castValue(value)
        case "gatewayports":                  self.gatewayPorts                 = try castValue(value)
        case "kbdinteractiveauthentication":  self.kbdInteractiveAuthentication = try castValue(value)
        case "hostbasedauthentication":       self.hostbasedAuthentication      = try castValue(value)
        case "hostkeyalgorithms":             self.hostKeyAlgorithms            = try castValue(value)
        case "hostname":                      self.hostName                     = try castValue(value)
        case "identityfile":                  self.identityFile                 = try castList(value)
        //case "identitiesonly":          self.identitiesOnly         = try castValue(value)
        case "kexalgorithms":                 self.kexAlgorithms                = try castValue(value)
        case "localforward":                  self.localForward                 = try castList(value)
        case "loglevel":                      self.logLevel                     = try castValue(value)
        case "macs":                          self.macs                         = try castValue(value)
        //case "numberofpasswordprompts": self.numberOfPasswordPrompts= try castValue(value)
        case "password":                      self.password                     = try castValue(value)
        case "passwordauthentication":        self.passwordAuthentication       = try castValue(value)
        case "port":                          self.port                         = try castValue(value)
        //case "preferredAuthentications":self.preferredAuthentications=try castValue(value)
        case "proxycommand":                  self.proxyCommand                 = try castValue(value)
        case "proxyjump":                     self.proxyJump                    = try castValue(value)
        case "pubkeyauthentication":          self.pubKeyAuthentication         = try castValue(value)
        case "rekeylimit":                    self.rekeyLimit                   = try castValue(value)
        case "remotecommand":                 self.remoteCommand                = try castValue(value)
        case "remoteforward":                 self.remoteForward                = try castList(value)
        case "requesttty":                    self.requestTty                   = try castValue(value)
        case "sendenv":                       self.sendEnv                      = try castList(value)
        case "stricthostkeychecking":         self.strictHostKeyChecking        = try castValue(value)
        case "user":                          self.user                         = try castValue(value)

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
      compressionLevel: compressionLevel,
      ciphers: ciphers,
      macs: macs,
      bindAddress: bindAddress,
      hostKeyAlgorithms: hostKeyAlgorithms,
      rekeyDataLimit: rekeyLimit?.rawValue,
      kexAlgorithms: kexAlgorithms,
      kbdInteractiveAuthentication: kbdInteractiveAuthentication,
      passwordAuthentication: passwordAuthentication,
      pubKeyAuthentication: pubKeyAuthentication,
      hostbasedAuthentication: hostbasedAuthentication,
      gatewayPorts: gatewayPorts
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

extension UInt: SSHValue {
  fileprivate init(castSSHValue val: String) throws {
    guard let _ = UInt(val) else {
      throw BKSSHHost.ValidationError(message: "Value must be a positive integer.")
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

public enum TTYBool: String, SSHValue {
  case auto  = "auto"
  case force = "force"
  case yes   = "yes"
  case no    = "no"

  fileprivate init(castSSHValue val: String) throws {
    guard let _ = TTYBool(rawValue: val) else {
      throw BKSSHHost.ValidationError(message: "Value must be auto, force, yes or no")
    }
    self.init(rawValue: val)!
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

fileprivate let AddressPattern = #"^((?<localPort>\d+)(:|\s))?(?<bindAddress>\[([\w:.][\w:.-]*)\]|([\w.][\w.-]*)):(?<remotePort>\d+)$"#

public struct PortForwardInfo: Equatable, SSHValue {
  public let remotePort: UInt16
  public let bindAddress: String
  public let localPort: UInt16

  fileprivate init(castSSHValue val: String) throws {
    try self.init(val)
  }

  public init(_ info: String) throws {
    let regex = try! NSRegularExpression(pattern: AddressPattern)

    guard let match = regex.firstMatch(in: info,
                                       range: NSRange(location: 0, length: info.count))
    else {
      throw BKSSHHost.ValidationError(message: "Missing <localport>:<bind_address>:<remoteport> for port forwarding.")
    }
    guard let r = Range(match.range(withName: "localPort"), in: info),
          let localPort = UInt16(info[r])
    else {
      throw BKSSHHost.ValidationError(message: "Invalid local port.")
    }
    self.localPort = localPort

    guard let r = Range(match.range(withName: "remotePort"), in: info),
          let remotePort = UInt16(info[r])
    else {
      throw BKSSHHost.ValidationError(message: "Invalid remote port.")
    }
    self.remotePort = remotePort

    guard let r = Range(match.range(withName: "bindAddress"), in: info)
    else {
      throw BKSSHHost.ValidationError(message: "Invalid bind address.")
    }
    var bindAddress = String(info[r])
    bindAddress.removeAll(where: { $0 == "[" || $0 == "]" })
    self.bindAddress = bindAddress
  }
}

public struct BindAddressInfo: Equatable, SSHValue {
  public let port: UInt16
  public let bindAddress: String

  fileprivate init(castSSHValue val: String) throws {
    try self.init(val)
  }

  public init(_ info: String) throws {
    let addr = try OptionalBindAddressInfo(info)

    guard let bindAddress = addr.bindAddress else {
      throw BKSSHHost.ValidationError(message: "Invalid bind address.")
    }

    self.bindAddress = bindAddress
    self.port  = addr.port
  }
}

public struct OptionalBindAddressInfo: Equatable, SSHValue {
  public let port: UInt16
  public let bindAddress: String?

  fileprivate init(castSSHValue val: String) throws {
    try self.init(val)
  }

  public init(_ info: String) throws {
    if let port = UInt16(info) {
      self.port = port
      self.bindAddress = nil
      return
    }

    let regex = try! NSRegularExpression(pattern: AddressPattern)

    guard let match = regex.firstMatch(in: info,
                                       range: NSRange(location: 0, length: info.count))
    else {
      throw BKSSHHost.ValidationError(message: "Missing <bind_address>:<remoteport>.")
    }

    guard let r = Range(match.range(withName: "remotePort"), in: info),
          let port = UInt16(info[r])
    else {
      throw BKSSHHost.ValidationError(message: "Invalid remote port.")
    }
    self.port = port

    if let r = Range(match.range(withName: "bindAddress"), in: info) {
      var bindAddress = String(info[r])
      bindAddress.removeAll(where: { $0 == "[" || $0 == "]" })
      self.bindAddress = bindAddress
    } else {
      throw BKSSHHost.ValidationError(message: "Invalid bind address.")
    }

  }
}

public struct BytesNumber: SSHValue {
  let rawValue: UInt

  fileprivate init(castSSHValue val: String) throws {
    guard let lastChar = val.last else {
      throw BKSSHHost.ValidationError(message: "Missing string")
    }

    if lastChar.isNumber {
      self.rawValue = try UInt(castSSHValue: val)
      return
    }

    var number = try UInt(castSSHValue: String(val.dropLast()))

    switch lastChar {
    case "G":
      number = number * 1024
      fallthrough
    case "M":
      number = number * 1024
      fallthrough
    case "K":
      number = number * 1024
    default:
      throw BKSSHHost.ValidationError(message: "Invalid bytes number.")
    }

    self.rawValue = number
  }
}
