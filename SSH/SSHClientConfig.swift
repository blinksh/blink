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

import Combine
import Foundation

import LibSSH


// TODO: check libssh api for string values
extension ssh_options_e {
  var name: String {
    switch self {
    case SSH_OPTIONS_HOST:              return "SSH_OPTIONS_HOST"
    case SSH_OPTIONS_USER:              return "SSH_OPTIONS_USER"
    case SSH_OPTIONS_LOG_VERBOSITY:     return "SSH_OPTIONS_LOG_VERBOSITY"
    case SSH_OPTIONS_COMPRESSION_C_S:   return "SSH_OPTIONS_COMPRESSION_C_S"
    case SSH_OPTIONS_COMPRESSION_S_C:   return "SSH_OPTIONS_COMPRESSION_S_C"
    case SSH_OPTIONS_COMPRESSION:       return "SSH_OPTIONS_COMPRESSION"
    case SSH_OPTIONS_COMPRESSION_LEVEL: return "SSH_OPTIONS_COMPRESSION_LEVEL"
    case SSH_OPTIONS_PORT_STR:          return "SSH_OPTIONS_PORT_STR"
    case SSH_OPTIONS_PROXYJUMP:         return "SSH_OPTIONS_PROXYJUMP"
    case SSH_OPTIONS_PROXYCOMMAND:      return "SSH_OPTIONS_PROXYCOMMAND"
    case SSH_OPTIONS_SSH_DIR:           return "SSH_OPTIONS_SSH_DIR"
    default:                            return "raw: \(rawValue)"
    }
  }
}

/**
 Delegates the responsability of interpreting a "Yes"/"Si"/"да" to the app.
 Should return a `.affirmative` if it's a positive answer.
 */
public enum InteractiveResponse {
  /// "Yes"/"Si"/"да"
  case affirmative
  /// "No"/"No"/"нет"
  case negative
}

/**
 Delegates the responsability of implementing and handling the cases.
 */
public enum VerifyHost {
  case changed(serverFingerprint: String)
  case unknown(serverFingerprint: String)
  case notFound(serverFingerprint: String)
}

// TODO Having the middle-man here to parse the config will allow us to then
// use the same defaults, etc... as with the SSHClientConfig, so we can abstract,
// modify, and adapt to our use cases.

public struct SSHClientConfig: CustomStringConvertible, Equatable {
  let user: String
  let port: String
  
  // TODO We could pass a callbacks type on dial instead of here.
  public typealias RequestVerifyHostCallback = (VerifyHost) -> AnyPublisher<InteractiveResponse, Error>
  
  /**
   List of all of the authentication methods to use. Priority in which they are tried is not tied to their position on the list, defined in `SSHClient.validAuthMethods()`.
   1. Publickey
   2. Password
   3. Keyboard Interactive
   4. Hostbased
   */
  var authenticators: [Authenticator] = []
  var agent: SSHAgent?

  /// `.ssh` path location
  let sshDirectory: String?
  /// Path to config file
  let sshClientConfigPath: String?
  /// If `nil` no host verification will be done
  let requestVerifyHostCallback: RequestVerifyHostCallback?
  
  let logger: SSHLogPublisher?
  /// Default verbosity logging is disabled, SSH_LOG_NOLOG
  let loggingVerbosity: SSHLogLevel
  
  let keepAliveInterval: Int? = nil
  
  let proxyCommand: String?
  let proxyJump: String?
  
  let connectionTimeout: Int
  
  let compression: Bool
  let compressionLevel: Int
  
  // TODO We can still offer this as a way to show what went through and simplify.
  // We may have enough with the one coming from the new BKConfig.
  public var description: String { """
  user: \(user)
  port: \(port)
  authenticators: \(authenticators.map { $0.displayName }.joined(separator: ", "))
  proxyJump: \(proxyJump)
  proxyCommand: \(proxyCommand)
  compression: \(compression)
  compressionLevel: \(compressionLevel)
  """}

  /**
   - Parameters:
   - user:
   - port: Default will be `22`
   - authMethods: Different authentication methods to try
   - loggingVerbosity: Default LibSSH logging shown is `SSH_LOG_NOLOG`
   - verifyHostCallback:
   - terminalEmulator:
   - sshDirectory: `ssh` directory, if `nil` it will use the default directory
   - keepAliveInterval: if `nil` it won't send KeepAlive packages from Client to the Server
   */
  public init(user: String,
              port: String? = nil,
              proxyJump: String? = nil,
              proxyCommand: String? = nil,
              authMethods: [AuthMethod]? = nil,
              agent: SSHAgent? = nil,
              loggingVerbosity: SSHLogLevel? = nil,
              verifyHostCallback: RequestVerifyHostCallback? = nil,
              connectionTimeout: Int? = nil,
              sshDirectory: String? = nil,
              sshClientConfigPath: String? = nil,
              logger: SSHLogPublisher? = nil,
              keepAliveInterval: Int? = nil,
              compression: Bool? = nil,
              compressionLevel: Int? = nil) {
    // We do our own constructor because the automatic one cannot define optional params.
    self.user = user
    self.port = port ?? "22"
    self.proxyCommand = proxyCommand
    self.proxyJump = proxyJump
    self.agent = agent
    self.loggingVerbosity = loggingVerbosity ?? .none
    self.requestVerifyHostCallback = verifyHostCallback
    self.sshDirectory = sshDirectory
    self.sshClientConfigPath = sshClientConfigPath
    self.logger = logger
    self.connectionTimeout = connectionTimeout ?? 30
    self.compression = compression ?? false
    self.compressionLevel = compressionLevel ?? 6
    
    // TODO Disable Keep Alive for now. LibSSH is not processing correctly the messages
    // that may come back from the server.
    // self.keepAliveInterval = keepAliveInterval
    
    authMethods?.forEach({ auth in
      if let auth = (auth as? Authenticator) {
        self.authenticators.append(auth)
      }
    })
  }
  
  public static func == (lhs: SSHClientConfig, rhs: SSHClientConfig) -> Bool {
    return (lhs.port == rhs.port &&
      lhs.user == rhs.user)
  }
}
